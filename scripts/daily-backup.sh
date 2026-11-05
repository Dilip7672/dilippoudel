#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${SITE:-lms.localhost}"
BENCH="${BENCH:-$HOME/.local/bin/bench}"
KEEP_DAYS="${KEEP_DAYS:-14}"

cd "$BENCH_DIR"

echo "[$(date -Is)] backup start for $SITE"
"$BENCH" --site "$SITE" backup --with-files

backup_dir="$BENCH_DIR/sites/$SITE/private/backups"
if [ -d "$backup_dir" ]; then
  find "$backup_dir" -type f \
    \( -name '*-database.sql.gz' -o -name '*-files.tar' -o -name '*-private-files.tar' -o -name '*-site_config_backup.json' \) \
    -mtime +"$KEEP_DAYS" -delete
fi

echo "[$(date -Is)] backup done"
