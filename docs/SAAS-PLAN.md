# Multi-Tenant LMS SaaS — Detailed Plan

## 1. Goal

Institutes sign up on your platform, get an isolated LMS, and run it on:

- `institute.yourplatform.com` (your subdomain), or
- `lms.institute.com` (their custom domain).

Each tenant sees only its own users, courses, content, payments, and settings.
They get a **scoped Desk** for useful customization (certificates, branding,
users, LMS settings) but cannot install apps, touch the server, or see other
tenants.

---

## 2. Core architecture: two layers

### A. Control plane (platform)

- Marketing site + signup + billing + provisioning + tenant management.
- Own database, own users, own admin console.
- Talks to infrastructure to create/manage tenant sites.
- Source of truth for tenant state, plans, subscriptions, domains, backups,
  and audit logs.

**Implementation options**

| Option | What it is | Best for |
|---|---|---|
| Adopt `frappe/press` | Open-source control plane behind Frappe Cloud; includes provisioning, domains, TLS, backups, plans, Stripe billing, monitoring | Fast path to production-grade |
| Thin custom control plane | Separate Frappe site + provisioning worker calling bench | MVP, unusual pricing/flows |
| WordPress + custom provisioner | WP for marketing/checkout, separate service does provisioning | Teams strong in WordPress |

Do **not** put the control plane inside a tenant site. It must be isolated.

### B. Tenant sites (data plane)

- One Frappe site per institute (separate DB, files, cache namespace).
- Apps: `frappe` + `payments` + `lms`.
- Routed by hostname (subdomain or custom domain).
- Each tenant's data is physically isolated.

This is the only model that cleanly supports per-tenant domains, branding,
isolation, and upgrades.

---

## 3. Tenancy model (decision)

| Model | Isolation | Custom domains | Effort | Verdict |
|---|---|---|---|---|
| Site-per-tenant | Strong (separate DB/files) | Natural | Medium | **Recommended** |
| Single site + tenant field | Weak (row-level) | Hard | High custom work | Avoid for LMS |
| One server/bench per tenant | Strongest | Natural | Expensive | Only for enterprise tier |

Start with **site-per-tenant on shared infrastructure**; offer dedicated
instances as an enterprise add-on.

---

## 4. Domain & TLS strategy

### Subdomains (MVP)

- Wildcard DNS: `*.yourplatform.com` -> ingress/load balancer.
- Wildcard TLS certificate (Let's Encrypt DNS-01) covers all subdomains.
- Wildcard nginx/server config routes by `Host`; Frappe resolves the site from
  hostname.
- Subdomain rules: length, allowed chars, reserved words, profanity filter,
  uniqueness, no impersonation.

### Custom domains (Phase 2)

- Tenant adds `lms.institute.com` -> CNAME to `yourplatform.com` (or A record).
- Verify ownership via DNS TXT/CNAME challenge before activation.
- Issue a per-domain certificate (HTTP-01 through nginx, or DNS-01).
- Register domain as an alias of the tenant site; add nginx server block.
- Auto-renew certificates; monitor expiry; alert on failure.
- Enforce HTTPS, HSTS, apex/www redirect policy.
- One domain maps to exactly one tenant; release on cancellation; prevent
  takeover.

### Email domains

- Default: send from `notifications@yourplatform.com` with tenant display name.
- Enterprise: tenant custom domain email requires their SPF/DKIM/DMARC setup.

---

## 5. Signup & provisioning flow

1. Visitor starts signup: institute name, owner email, password/SSO, country,
   plan.
2. Verify email + captcha/rate limit + terms acceptance.
3. Choose subdomain (live availability check) and plan.
4. Start trial or collect payment via Stripe Checkout.
5. Create a **provisioning job** (never do this in the web request):
   `queued -> validating -> creating_site -> installing_apps -> seeding_admin
   -> configuring -> active` (or `failed`).
6. Provisioning worker performs:
   - Create site with unique DB/user and secrets.
   - Install `frappe`, `payments`, `lms`.
   - Create tenant owner as scoped Institute Admin.
   - Apply branding, defaults, feature flags, limits.
   - Set host name, website settings, email config.
   - Build assets, run migrations.
   - Provision subdomain routing (wildcard already covers it).
   - If custom domain requested: start verification + cert job.
   - Send welcome email with login URL.
7. Show live progress page; retry/rollback on failure.
8. Idempotent steps + locks so retries are safe.

**Failure handling**: automatic rollback (delete partial site), error surfaced
to platform admin, tenant notified, job retry with backoff.

---

## 6. Tenant lifecycle

States: `trial -> active -> past_due -> suspended -> cancelled -> deleted`.

- **Trial**: time-limited, feature-limited.
- **Active**: normal.
- **Past due**: grace period, warnings.
- **Suspended**: read-only or login-blocked (configurable), data retained.
- **Cancelled**: data export window, then scheduled deletion.
- **Deleted**: hard delete after retention; keep audit record.

Automated emails at each transition; admin can override.

---

## 7. Roles, Desk scoping, whitelabel

### Platform roles

- Platform Owner / Super Admin.
- Support (audited impersonation, no raw DB access).
- Billing Admin.
- Read-only Auditor.

### Tenant roles

- Institute Owner/Admin -> scoped Desk role (LMS doctypes, Print Formats, Users,
  Website Settings, LMS Settings).
- Moderator / Instructor / Student -> LMS built-in roles.
- Custom "Institute Admin" role using Role Permissions + User Permissions.
- Optional "LMS-only" plan: no Desk, only LMS portal.

### Desk restrictions

- Hide unrelated workspaces/doctypes; show a clean tenant admin panel.
- Disable `developer_mode`, Server Scripts, and anything allowing code
  execution.
- Prevent app install/upgrade, site config, backups, domain/SSL changes
  (platform-only).
- Restrict dangerous actions (delete all data, raw SQL, bench access).
- Audit all admin actions.

### Whitelabel

- Logo, favicon, colors, login page, email templates, certificate templates.
- Hide Frappe branding/help links where allowed.
- Custom domain makes it feel like their product.

### SSO

- MVP: separate logins per tenant.
- Later: platform-level identity provider (OAuth/SAML) for enterprise;
  cross-domain SSO is non-trivial, so scope carefully.

---

## 8. Plans, limits, feature flags

Suggested tiers:

- **Starter**: subdomain, limited users/storage/courses, LMS only.
- **Growth**: custom domain, branding, certificates, payments, more limits.
- **Enterprise**: SSO, API, dedicated resources, SLA, priority support.

Limits to enforce:

- Active users, storage, courses, enrollments, bandwidth, custom domains, API
  calls.
- Feature flags: custom domain, certificates, payments, SSO, API, branding,
  analytics.

Enforcement:

- Pre-checks at user creation/upload.
- Scheduled usage audit + overage warnings.
- Grace behavior before hard limits.

---

## 9. Billing (two separate layers)

### Layer 1 — Platform billing (what institutes pay you)

- Owned by the control plane.
- `frappe/press` provides plans, subscriptions, invoices, Stripe integration,
  trials, and billing history out of the box (self-hosting requires Stripe
  setup, plan configuration, and testing).
- Custom control plane: integrate Stripe Checkout/subscriptions/webhooks,
  plan catalog, proration, tax, dunning, invoices.
- Dunning -> past_due -> suspension policy; usage-based add-ons.
- Link subscription to the tenant/site record.

### Layer 2 — Tenant course payments (what students pay institutes)

- Lives inside each tenant site via the `payments` app.
- The institute connects its own Stripe account; revenue is theirs.
- Never mix this with platform billing or the platform's Stripe account.

The two layers must remain separate: platform revenue vs tenant revenue.

---

## 10. Data isolation & security

- Separate DB + files per site; per-site DB credentials.
- Per-site cache keys/namespaces; no cross-tenant cache leakage.
- Secrets stored in a vault/control plane, never Git.
- DB server not publicly exposed; tenant DB users scoped.
- Private files access-controlled; object storage with signed URLs if used.
- Encrypted backups, offsite storage.
- Rate limiting, WAF, bot protection on signup/login.
- Audit logs for provisioning, impersonation, billing, admin actions.
- GDPR: data export, deletion, retention policy, DPA.
- Dependency/secret scanning in CI.
- Isolation tests: tenant A cannot read B via URL, API, files, or cache.

---

## 11. Infrastructure & scaling

### MVP

- One VM/bench with nginx, MariaDB, Redis, workers.
- Wildcard DNS + TLS; systemd/cron; local or S3 backups.
- Single bench group.

### Growth

- Separate DB and Redis servers.
- Multiple app servers behind a load balancer.
- Object storage for files/backups; CDN for assets.
- Bench groups by app version/plan.
- Per-site resource limits to avoid noisy neighbors.

### Scale

- Containers/Kubernetes; autoscaling.
- Dedicated worker pools; queue partitioning.
- HA DB (replication/failover), Redis HA, multi-AZ.
- Blue/green or canary upgrades.

### Bench strategy

- Pin Frappe/LMS/payments versions per bench group.
- Upgrade in waves: staging -> canary tenants -> all.
- Never upgrade all tenants at once.

---

## 12. Backups, upgrades, disaster recovery

- Per-tenant daily backups (DB + files), encrypted, offsite, retention policy.
- Extra backup before every upgrade or migration.
- Restore runbook per tenant; test restores regularly.
- Version pinning per tenant/bench; migration jobs with status.
- Maintenance mode per tenant; rollback via backup + code tag.
- Platform-level DR: infrastructure snapshots, DB backups, config backups.

---

## 13. Monitoring, logging, support

- Uptime checks per tenant domain; SSL expiry monitoring.
- Metrics: latency, errors, queue depth, DB health, disk, per-tenant usage.
- Centralized logs + error tracking (e.g., Sentry).
- Alerting (Slack/PagerDuty); status page.
- Support: ticketing, audited impersonation, tenant health view.
- Provisioning dashboard with job states and retries.

---

## 14. Email

- Shared transactional provider (SES/Postmark) for platform + tenant
  notifications.
- Per-tenant From name; enterprise custom domain with SPF/DKIM/DMARC.
- Bounce/complaint handling, rate limits.
- Branded templates per tenant.

---

## 15. Platform admin console

- Tenants: list, status, plan, usage, version, domains, last backup.
- Actions: provision, retry, suspend, cancel, delete, impersonate (audited).
- Billing: invoices, coupons, refunds, dunning.
- Domains/SSL: verification status, cert expiry, renew.
- Backups/restores and upgrade scheduling.
- Feature flags, announcements, maintenance windows.
- Support tickets and audit log.

---

## 16. Compliance & abuse prevention

- Terms, privacy policy, DPA, data residency options.
- Email verification, captcha, rate limits, disposable-email blocking.
- Reserved subdomains and trademark checks.
- Spam/abuse monitoring; suspend policy.
- Content moderation hooks (optional).
- Data export/delete workflows.

---

## 17. Testing strategy

- Provisioning integration tests (create -> install -> destroy).
- Tenant isolation tests (URLs, API, files, cache, DB).
- Domain/TLS tests in staging (subdomain + custom domain).
- Billing webhook tests (Stripe CLI), dunning simulations.
- Upgrade/rollback tests; restore drills.
- Load and failover tests; security/pen tests; secrets scanning.

---

## 18. Phased roadmap

| Phase | Scope | Duration (1-2 devs) |
|---|---|---|
| 0. Foundation | Tenancy decision, control-plane choice, wildcard DNS/TLS, repo/CI, infra baseline | 2-4 weeks |
| 1. MVP | Signup, subdomain, async provisioning, LMS install, scoped admin, welcome email, manual/simple billing, daily backups, basic monitoring | 6-10 weeks |
| 2. Production | Stripe subscriptions + limits + dunning, custom domains + SSL automation, lifecycle states, offsite backups, upgrade pipeline, audit, support tools | 8-12 weeks |
| 3. Scale/Enterprise | Multi-bench/containers, HA, SSO, API, advanced branding, analytics, SLA, dedicated instances | Ongoing |

Realistic: **MVP ~2-3 months**, **production ~4-6 months**, **full scale
9-12+ months**.

---

## 19. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Provisioning failures | Idempotent jobs, retries, rollback, staging tests |
| Custom-domain/SSL complexity | Verify ownership, per-domain cert automation, expiry alerts |
| Noisy neighbors | Per-site limits, containers/cgroups, separate DB/Redis tiers |
| Upgrade breakage across tenants | Version pinning, canary waves, backups before upgrade |
| Billing edge cases | Stripe webhooks + reconciliation, dunning tests |
| Signup abuse/spam | Captcha, email verification, rate limits, reserved names |
| Data privacy | Encryption, isolation tests, audit logs, GDPR workflows |
| Support load | Self-serve onboarding, docs, health dashboards, ticketing |

---

## 20. Control plane decision: Frappe Press vs custom

**`frappe/press`** is the open-source control plane behind Frappe Cloud. It
includes:

- Site creation/provisioning, suspend/delete
- Plans, subscriptions, invoices, Stripe billing, trials
- Subdomains, custom domains, TLS certificates
- Per-site backups, monitoring, usage, logs
- Agent/server management, bench groups, upgrades
- Platform admin console, support/impersonation, audit

It runs as its own Frappe app/site (separate DB) and drives the benches/sites
underneath.

**What Press does not give you for free**

- Your signup UX, pricing, and branding
- Your exact plan/limit rules and LMS feature packaging
- Custom onboarding/emails/support flows
- A fully white-label SaaS experience (customization still required)

**Trade-off**

| | Press | Custom control plane |
|---|---|---|
| Time to production | Faster | Slower |
| Code to write | ~500-2,000 LOC glue | ~5,000-10,000 LOC |
| Ops complexity | High (opinionated) | High (you build it) |
| Flexibility | Constrained by its model | Full control |
| Billing | Included | Build with Stripe |
| Domains/TLS/backups | Included | Build/integrate |

**Recommendation**

1. Run a short Phase 0 spike: deploy Press on staging, create a tenant, map a
   subdomain, configure a plan + Stripe, run a backup/restore.
2. If it fits your pricing/flows, adopt Press and keep only product-specific
   glue (signup UX, LMS packaging, branding).
3. If it fights your model, build a thin custom control plane and reuse
   components (Stripe, cert-manager/Let's Encrypt, S3).
4. Do not build both. Pick one at the end of Phase 0.

---

## 21. Suggested repository layout (conceptual)

- `platform/` — control-plane app (tenants, plans, jobs, domains, billing).
- `provisioner/` — worker/service that creates and manages tenant sites.
- `deploy/` — nginx, systemd/containers, DNS/TLS, IaC.
- `docs/` — runbooks: provisioning, domain, restore, upgrade, incident.
- `tests/` — integration, isolation, billing, upgrade.

---

## 22. Decisions needed

1. Control plane: adopt `frappe/press` or build a thin custom one? (Decision
   gate at the end of Phase 0.)
2. Marketing site: Frappe page, WordPress, or separate static site? (Keep it
   separate from the control plane either way.)
3. Shared bench vs dedicated instances for paid tiers?
4. Which plans/limits and what is free vs paid?
5. Custom domains at launch or after MVP?
6. Do tenants get Desk by default, or only on higher plans?
7. Single region or multi-region/data residency?
8. Billing provider (Stripe) and tax handling?
9. SSO/enterprise features timeline?
