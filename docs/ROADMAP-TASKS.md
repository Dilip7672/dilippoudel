# Roadmap — Phase 0 & Phase 1 Task Checklist

Scope: reach an MVP where an institute can sign up and get a working,
isolated LMS on `institute.yourplatform.com`, with a scoped Desk and daily
backups. Custom domains, full billing, HA, and SSO are Phase 2+.

---

## Phase 0 — Foundation (2-4 weeks)

### Decisions
- [ ] Confirm tenancy model: site-per-tenant.
- [ ] Decide control plane: adopt `frappe/press` or build custom (thin).
- [ ] Define plans and limits (users, storage, courses, features).
- [ ] Decide Desk policy: scoped Desk by default vs higher plans only.
- [ ] Decide custom-domain timeline (Phase 2 recommended).
- [ ] Decide region/hosting provider and data-residency needs.
- [ ] Choose billing provider (Stripe) and tax approach.

### Infrastructure baseline
- [ ] Register platform domain (e.g. `yourplatform.com`).
- [ ] Wildcard DNS `*.yourplatform.com` -> server/load balancer.
- [ ] Wildcard TLS (Let's Encrypt DNS-01) + auto-renewal.
- [ ] nginx/server config routing by `Host`; verify Frappe site resolution.
- [ ] MariaDB, Redis, bench, workers, systemd services on staging.
- [ ] Object storage (S3-compatible) for files/backups (recommended).
- [ ] Staging environment separate from production.

### Repo & CI
- [ ] Repo structure: `platform/`, `provisioner/`, `deploy/`, `docs/`,
      `tests/`.
- [ ] CI: lint, unit tests, secret scanning, dependency scan.
- [ ] Secrets management (vault/env), no secrets in Git.
- [ ] Branch/tag/checkpoint workflow (already started).
- [ ] Baseline monitoring + log aggregation.

### Security baseline
- [ ] Restrict DB/Redis to private network.
- [ ] SSH key-only access, firewall, fail2ban/WAF.
- [ ] Audit log design for admin/impersonation actions.
- [ ] Backup encryption and access policy.

---

## Phase 1 — MVP (6-10 weeks)

### Control plane
- [ ] Tenant model (name, subdomain, plan, status, owner, dates).
- [ ] Provisioning job model + state machine + status page.
- [ ] Signup page: institute details, owner account, plan.
- [ ] Subdomain availability check + reserved words + validation.
- [ ] Email verification, captcha/rate limit, terms acceptance.
- [ ] Trial/plan assignment (manual or basic Stripe).
- [ ] Platform admin console: tenants list, status, retry, suspend.
- [ ] Audit log for provisioning and admin actions.

### Provisioner
- [ ] Queue worker with locking (no provisioning in web request).
- [ ] Step: create site with unique DB/user/secrets.
- [ ] Step: install `frappe`, `payments`, `lms`.
- [ ] Step: create tenant owner as scoped Institute Admin.
- [ ] Step: apply branding/defaults/feature flags/limits.
- [ ] Step: set host name, website settings, email config.
- [ ] Step: build assets + migrate.
- [ ] Idempotency, retries with backoff, rollback on failure.
- [ ] Failure notifications to platform admin + tenant.

### Routing
- [ ] Wildcard subdomain -> tenant site by Host header.
- [ ] HTTPS enforced; redirects correct.
- [ ] 404/unknown-subdomain handling.
- [ ] Tenant suspended/maintenance page handling.

### Tenant admin & Desk scoping
- [ ] Custom "Institute Admin" role with LMS permissions.
- [ ] Hide unrelated workspaces/doctypes.
- [ ] Disable developer_mode, Server Scripts, app install/upgrade.
- [ ] Branding: logo, favicon, colors, login page.
- [ ] Tenant settings for certificates/print formats and LMS settings.
- [ ] Staff/instructor/student roles verified (LMS portal only).

### Email
- [ ] Transactional provider configured (SES/Postmark).
- [ ] Welcome email with login URL.
- [ ] Branded templates; per-tenant From name.
- [ ] Bounce handling basics.

### Billing (MVP)
- [ ] Plan catalog + trial (manual or Stripe Checkout).
- [ ] Link subscription to tenant; basic invoice record.
- [ ] Suspension rule for expired trial/payment (manual trigger ok).

### Backups & recovery
- [ ] Per-tenant daily DB + files backup.
- [ ] Offsite copy (S3 or external).
- [ ] Restore runbook tested on staging.
- [ ] Backup before upgrades/maintenance.

### Monitoring & support
- [ ] Uptime check per tenant domain.
- [ ] Error tracking + centralized logs.
- [ ] Provisioning dashboard with job states.
- [ ] Basic support workflow + audited impersonation.
- [ ] Status page (optional MVP).

### Testing
- [ ] Provisioning integration test (create -> install -> destroy).
- [ ] Tenant isolation test (A cannot access B via URL/API/files/cache).
- [ ] Subdomain routing + TLS test.
- [ ] Restore drill.
- [ ] Signup abuse/rate-limit test.

### Documentation
- [ ] Runbooks: provisioning, failed job, suspend, restore, incident.
- [ ] Tenant onboarding guide.
- [ ] Platform admin guide.
- [ ] Update `README.md` and `docs/`.

---

## MVP acceptance criteria

- [ ] A new institute can sign up and get a working LMS at
      `institute.yourplatform.com` within a few minutes.
- [ ] Tenant owner logs in and sees a scoped Desk + LMS portal.
- [ ] Students/instructors only see the LMS portal.
- [ ] Tenant A cannot access Tenant B's data by any route.
- [ ] Daily backups run and a restore has been proven on staging.
- [ ] Platform admin can retry failed provisioning, suspend, and delete a
      tenant.
- [ ] Basic trial/payment enforcement works.

---

## Explicitly out of scope for MVP (Phase 2+)

- Custom domains + per-domain SSL automation.
- Full Stripe subscriptions, dunning, usage metering.
- HA, multi-region, Kubernetes autoscaling.
- SSO/SAML, API, advanced analytics.
- Dedicated instances and enterprise SLAs.
- Marketplace/plugin system for tenants.
