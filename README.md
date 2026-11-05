# Frappe LMS Platform

Local development bench for a Frappe-based LMS (planned multi-tenant SaaS).
Secrets are **not** stored here; see `LOCAL-CREDENTIALS.md` (gitignored).

## Access

- Bench site: `lms.localhost`
- App URL: http://localhost:8000
- LMS frontend: http://localhost:8000/lms
- Desk (admin backend): http://localhost:8000/app
- Login: `Administrator` (password in `LOCAL-CREDENTIALS.md`)

From Windows, use `http://localhost:8000` (WSL2 forwards localhost).

## Stack / versions

| Component | Version |
|---|---|
| OS | Ubuntu 24.04 (WSL2) |
| Frappe | 17.0.0-dev (develop, commit df763b2) |
| LMS | 2.45.2 (develop) |
| Payments | 0.0.1 (develop) |
| bench | 5.31.1 |
| Python | 3.14.7 (uv-managed) |
| Node | 24.22.2 (nvm) |
| Yarn | 1.22.22 |
| MariaDB | 10.11.14 |
| Redis | 7 (bench-managed on 11000/13000) |

## Layout

- Bench: `~/frappe/my-bench`
- Apps: `apps/frappe`, `apps/lms`, `apps/payments` (upstream clones, each own git repo)
- Site: `sites/lms.localhost`
- Backups: `sites/lms.localhost/private/backups`
- Bench log: `logs/bench-start.log`, `~/frappe/bench.log`
- Scripts: `scripts/`

## Daily use

```bash
cd ~/frappe/my-bench

bench start                         # run in foreground (Ctrl+C to stop)
bench --site lms.localhost list-apps
bench --site lms.localhost migrate
bench build
```

Stop the background instance:

```bash
pkill -f 'bench (start|serve|socketio|watch|schedule|worker)'
pkill -f honcho
redis-cli -p 11000 shutdown nosave
redis-cli -p 13000 shutdown nosave
```

After a WSL restart, start MariaDB (if needed) and run `bench start`.

## Checkpoints (code + data)

Make a checkpoint **before every risky change**:

```bash
./scripts/checkpoint.sh "what changed"
PUSH=1 ./scripts/checkpoint.sh "what changed"   # also push to GitHub
```

This commits code, creates a `checkpoint-YYYYmmdd-HHMMSS` tag, backs up the
site database + public/private files, and records the mapping in `.checkpoints`.

List checkpoints:

```bash
git tag --list 'checkpoint-*' | tail -20
```

Restore to a checkpoint:

```bash
./scripts/restore.sh <checkpoint-tag>
```

This stops bench, checks out the tag, restores DB + files, runs `migrate` and
`build`, then restarts bench in the background. After restoring you are on a
detached HEAD; continue with:

```bash
git switch -C main <checkpoint-tag>
```

Environment overrides: `SITE`, `START` (0 = do not start bench),
`DB_ROOT_USER` / `DB_ROOT_PASSWORD` (default `frappe` / `frappe`),
`BENCH_DIR`.

## Automatic backups

- `scripts/daily-backup.sh`: DB + files, keeps 14 days.
- Cron: `15 2 * * *` (see `crontab -l`).
- Bench also runs a DB-only backup every 6 hours.
- Cron runs only while WSL is running.

Backups are local only. Copy them off the machine (S3, external drive) for
real protection.

## Git / GitHub

- Remote: `git@github.com:Dilip7672/dilippoudel.git` (SSH)
- Branch: `main`
- Tracked: `Procfile`, `patches.txt`, `.gitignore`, `scripts/`, docs
- Ignored: `apps/frappe`, `apps/lms`, `apps/payments`, `env/`, `sites/`,
  `config/`, `logs/`, `flow-server/`, secrets, `.checkpoints`

## Troubleshooting

- **Redis connection refused (11000/13000)**: bench services are down. Start
  bench, or run:
  `redis-server config/redis_cache.conf --daemonize yes` and
  `redis-server config/redis_queue.conf --daemonize yes`.
- **`bench migrate` says services not running**: start Redis first.
- **`bench build` fails with `yarn: not found`**: nvm Node/Yarn not in PATH.
  Add `~/.nvm/versions/node/v24.22.2/bin` to PATH (the restore script does this).
- **Restore prompts for MySQL root password**: pass
  `--db-root-username frappe --db-root-password frappe` (restore script does).
- **Site not loading**: check `logs/bench-start.log`, then `bench --site
  lms.localhost doctor` / `bench --site lms.localhost migrate`.

## Multi-tenant plan (future)

Use Frappe site-per-tenant: one site per institute (own DB/files/apps), a
separate control-plane site for signup/provisioning/billing, wildcard DNS +
TLS for `*.platform.com`, and custom domains as site aliases. Tenants can get
scoped Desk roles (certificates/print formats) without full System Manager.
