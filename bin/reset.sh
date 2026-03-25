#!/usr/bin/env bash

#
# reset.sh — Full project reset with confirmation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/setup/helpers.sh"
ENV_FILE="$ROOT_DIR/.env"

PM=$(detect_pm)
docker_compose() {
  docker compose -f "$ROOT_DIR/docker/docker-compose.yml" "$@"
}

echo ""
warn "${BOLD}This will delete:${NC}"
echo -e "    • Docker containers and volumes (database)"
echo -e "    • public/ (WordPress installation)"
echo -e "    • .env (configuration)"
echo -e "    • node_modules/, vendor/, package-lock.json, composer.lock"
echo -e "    • .setup-state"
echo ""
choose CHOICE 3 \
  "Reset now" \
  "Dump database first, then reset" \
  "Cancel"

DO_RESET="n"

case "$CHOICE" in
  1)
    DO_RESET="y"
    ;;
  2)
    # Dump first
    if [ -f "$ENV_FILE" ]; then
      DUMP_FILE="$ROOT_DIR/database/dump-$(date +%Y%m%d-%H%M%S).sql"
      info "Exporting database..."
      docker_compose --env-file "$ENV_FILE" exec -T db sh -c \
        'mysqldump --no-tablespaces -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" 2>/dev/null' \
        > "$DUMP_FILE" 2>/dev/null && \
        success "Database exported to $(basename "$DUMP_FILE")" || \
        warn "Could not export database (containers may not be running)"
    else
      warn "No .env file — skipping dump"
    fi
    DO_RESET="y"
    ;;
  *)
    info "Cancelled."
    ;;
esac

if [ "$DO_RESET" = "y" ]; then
  # Stop containers + remove volumes
  if [ -f "$ENV_FILE" ]; then
    info "Stopping Docker containers..."
    docker_compose --env-file "$ENV_FILE" down -v 2>/dev/null && \
      success "Containers and volumes removed" || true
  fi

  # Clean files
  rm -rf "${ROOT_DIR:?}/public" "${ROOT_DIR:?}/node_modules" "${ROOT_DIR:?}/vendor" "${ROOT_DIR:?}/.env" "${ROOT_DIR:?}/.setup-state" "${ROOT_DIR:?}/composer.lock"
  rm -f "${ROOT_DIR:?}/package-lock.json" "${ROOT_DIR:?}/pnpm-lock.yaml" "${ROOT_DIR:?}/yarn.lock" "${ROOT_DIR:?}/bun.lockb" "${ROOT_DIR:?}/bun.lock"
  success "Project reset. Run ${BOLD}$PM run setup${NC} to start fresh."
fi
