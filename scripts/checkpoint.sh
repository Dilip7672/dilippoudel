#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${SITE:-lms.localhost}"
BENCH="${BENCH:-$HOME/.local/bin/bench}"
MESSAGE="${1:-checkpoint}"
PUSH="${PUSH:-0}"

cd "$BENCH_DIR"

ts="$(date +%Y%m%d-%H%M%S)"
tag="checkpoint-${ts}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: $BENCH_DIR is not a git repository" >&2
  exit 1
fi

echo "==> Saving code"
git add -A
if git diff --cached --quiet; then
  echo "No code changes to commit."
else
  git commit -m "$MESSAGE ($ts)"
fi
git tag -a "$tag" -m "$MESSAGE"

echo "==> Backing up site: $SITE"
"$BENCH" --site "$SITE" backup --with-files

backup_dir="$BENCH_DIR/sites/$SITE/private/backups"
db_file="$(ls -t "$backup_dir"/*-database.sql.gz 2>/dev/null | head -1 || true)"
if [ -z "$db_file" ]; then
  echo "Error: backup not found in $backup_dir" >&2
  exit 1
fi

prefix="${db_file%-database.sql.gz}"
files_file="${prefix}-files.tar"
private_file="${prefix}-private-files.tar"

{
  echo "tag=$tag"
  echo "commit=$(git rev-parse HEAD)"
  echo "time=$ts"
  echo "site=$SITE"
  echo "prefix=$prefix"
  echo "---"
} >> "$BENCH_DIR/.checkpoints"

echo
echo "Checkpoint saved:"
echo "  tag:     $tag"
echo "  commit:  $(git rev-parse --short HEAD)"
echo "  db:      $db_file"
echo "  files:   $files_file"
echo "  private: $private_file"

if [ "$PUSH" = "1" ]; then
  echo "==> Pushing code + tag to origin"
  git push origin HEAD
  git push origin "$tag"
fi
