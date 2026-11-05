#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${SITE:-lms.localhost}"
BENCH="${BENCH:-$HOME/.local/bin/bench}"
TAG="${1:-}"
START="${START:-1}"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <checkpoint-tag> [backup-prefix]" >&2
  echo "Example: $0 checkpoint-20261105-075033" >&2
  echo "List checkpoints: git tag --list 'checkpoint-*' | tail -20" >&2
  exit 1
fi

cd "$BENCH_DIR"
backup_dir="$BENCH_DIR/sites/$SITE/private/backups"

echo "==> Stopping bench"
pkill -f 'bench (start|serve|socketio|watch|schedule|worker)' 2>/dev/null || true
pkill -f honcho 2>/dev/null || true
sleep 2

echo "==> Restoring code to $TAG"
git checkout -f "$TAG"

prefix="${2:-}"
if [ -z "$prefix" ]; then
  prefix="$(awk -v t="$TAG" '
    $0 == "tag=" t { found=1; next }
    found && /^prefix=/ { sub(/^prefix=/, ""); print; exit }
  ' "$BENCH_DIR/.checkpoints" 2>/dev/null || true)"
fi

if [ -z "$prefix" ]; then
  db_latest="$(ls -t "$backup_dir"/*-database.sql.gz 2>/dev/null | head -1 || true)"
  [ -n "$db_latest" ] && prefix="${db_latest%-database.sql.gz}"
fi

if [ -z "$prefix" ]; then
  echo "Error: no backup found. Code was restored, but the database was not." >&2
  exit 1
fi

db_file="${prefix}-database.sql.gz"
files_file="${prefix}-files.tar"
private_file="${prefix}-private-files.tar"

if [ ! -f "$db_file" ]; then
  echo "Error: database backup missing: $db_file" >&2
  exit 1
fi

echo "==> Restoring database + files"
args=(--site "$SITE" restore "$db_file" --force)
[ -f "$files_file" ] && args+=(--with-public-files "$files_file")
[ -f "$private_file" ] && args+=(--with-private-files "$private_file")
"$BENCH" "${args[@]}"

echo "==> Migrating + building"
"$BENCH" --site "$SITE" migrate
"$BENCH" build

if [ "$START" = "1" ]; then
  echo "==> Starting bench in background"
  nohup setsid "$BENCH" start > "$BENCH_DIR/logs/bench-start.log" 2>&1 < /dev/null &
  sleep 5
  echo "Bench starting; check: $BENCH_DIR/logs/bench-start.log"
fi

echo "Restore complete. Code at: $(git describe --tags --always)"
