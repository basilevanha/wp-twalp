#!/usr/bin/env bash

#
# import.sh — Import a database dump into the running WordPress Docker environment
#
# Usage: npm run import [-- database/dump-20260319-143052.sql]
#

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✔${NC}  $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✖${NC}  $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

# Check .env exists
if [ ! -f "$ENV_FILE" ]; then
  error "No .env file found. Run ${BOLD}npm run setup${NC} first."
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

DOCKER_COMPOSE_CMD="docker compose -f $ROOT_DIR/docker/docker-compose.yml --env-file $ENV_FILE"

# Check containers are running
if ! $DOCKER_COMPOSE_CMD ps --status running 2>/dev/null | grep -q "db"; then
  error "Docker containers are not running. Run ${BOLD}npm run dev${NC} first."
  exit 1
fi

# Determine which file to import
SQL_FILE="${1:-}"

if [ -z "$SQL_FILE" ]; then
  # List available dumps
  DUMP_FILES=()
  while IFS= read -r -d '' f; do
    DUMP_FILES+=("$f")
  done < <(find "$ROOT_DIR/database" -name "dump-*.sql" -print0 2>/dev/null | sort -rz)

  if [ "${#DUMP_FILES[@]}" -eq 0 ]; then
    error "No dump files found in database/"
    exit 1
  fi

  echo ""
  info "Available database dumps:"
  echo ""
  i=1
  for f in "${DUMP_FILES[@]}"; do
    fname=$(basename "$f")
    fsize=$(du -h "$f" | cut -f1 | tr -d ' ')
    if [ "$i" -eq 1 ]; then
      echo -e "  ${CYAN}→${NC} ${BOLD}${i})${NC} ${fname} (${fsize})"
    else
      echo -e "    ${i}) ${fname} (${fsize})"
    fi
    i=$((i + 1))
  done
  echo ""
  read -rp "$(echo -e "${BOLD}Choose${NC} [1]: ")" CHOICE
  CHOICE="${CHOICE:-1}"

  idx=$((CHOICE - 1))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#DUMP_FILES[@]}" ]; then
    error "Invalid choice"
    exit 1
  fi
  SQL_FILE="${DUMP_FILES[$idx]}"
fi

# Verify file exists
if [ ! -f "$SQL_FILE" ]; then
  error "File not found: $SQL_FILE"
  exit 1
fi

# WP-CLI wrapper
run_wp() {
  $DOCKER_COMPOSE_CMD exec -T wordpress wp --allow-root "$@"
}

# Import
info "Importing $(basename "$SQL_FILE")..."
$DOCKER_COMPOSE_CMD exec -T db sh -c \
  'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" 2>/dev/null' \
  < "$SQL_FILE"
success "Database imported"

# Search-replace URLs
NEW_URL="http://localhost:${WP_PORT:-8080}"
IMPORTED_URL=$(run_wp option get siteurl 2>/dev/null || true)

if [ -n "$IMPORTED_URL" ] && [ "$IMPORTED_URL" != "$NEW_URL" ]; then
  info "Replacing URLs: $IMPORTED_URL → $NEW_URL"
  run_wp search-replace "$IMPORTED_URL" "$NEW_URL" --all-tables --skip-columns=guid 2>/dev/null && \
    success "URLs updated" || warn "Could not update URLs"
fi

# Flush
run_wp cache flush 2>/dev/null || true
run_wp rewrite flush 2>/dev/null || true

success "Import complete. Open ${BOLD}${NEW_URL}${NC}"
