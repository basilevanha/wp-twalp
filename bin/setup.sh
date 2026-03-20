#!/usr/bin/env bash

#
# setup.sh — Interactive setup CLI for the WordPress boilerplate
#
# Usage: npm run setup (or bash bin/setup.sh)
#

set -euo pipefail

# ──────────────────────────────────────────────
# Resolve paths
# ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
STATE_FILE="$ROOT_DIR/.setup-state"
SETUP_DIR="$SCRIPT_DIR/setup"

# ──────────────────────────────────────────────
# Load helpers & detect package manager
# ──────────────────────────────────────────────
source "$SETUP_DIR/helpers.sh"
PM=$(detect_pm)

# ──────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────
source "$SETUP_DIR/preflight.sh"

# ──────────────────────────────────────────────
# Error trap — keep state file on failure
# ──────────────────────────────────────────────
on_error() {
  local exit_code=$?
  if [ $exit_code -ne 0 ] && [ -f "$STATE_FILE" ]; then
    echo ""
    warn "Setup interrupted (exit code: $exit_code)."
    info "Your answers have been saved. Re-run ${BOLD}$PM run setup${NC} to resume."
  fi
}
trap on_error EXIT

# ──────────────────────────────────────────────
# Welcome
# ──────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "  ${BOLD}║   WordPress Boilerplate — Setup CLI      ║${NC}"
echo -e "  ${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ──────────────────────────────────────────────
# Resume from saved state?
# ──────────────────────────────────────────────
SKIP_QUESTIONS="n"

if [ -f "$STATE_FILE" ]; then
  warn "A previous setup was interrupted."
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  echo ""
  info "Saved answers:"
  echo -e "      Project:   ${BOLD}$PROJECT_NAME${NC}"
  echo -e "      WP setup:  ${BOLD}$([ "${WP_SETUP_MODE:-1}" = "1" ] && echo "Automatic ($WP_ADMIN_USER)" || echo "Vanilla")${NC}"
  echo -e "      ACF:       ${BOLD}$USE_ACF${NC}"
  echo ""
  ask_yn "Resume with these answers?" "y" RESUME
  if [ "$RESUME" = "y" ]; then
    SKIP_QUESTIONS="y"
    success "Resuming with saved answers"
  else
    rm "$STATE_FILE"
    info "Starting fresh"
  fi
fi

# ──────────────────────────────────────────────
# 1. Interactive questions
# ──────────────────────────────────────────────
source "$SETUP_DIR/questions.sh"

# ──────────────────────────────────────────────
# 2. Configuration (.env, theme metadata, ACF, dependencies)
# ──────────────────────────────────────────────
source "$SETUP_DIR/configure.sh"

# ──────────────────────────────────────────────
# 3. CSS/JS frameworks + front-page template
# ──────────────────────────────────────────────
source "$SETUP_DIR/frameworks.sh"

# ──────────────────────────────────────────────
# 4. Docker containers + initial sync
# ──────────────────────────────────────────────
source "$SETUP_DIR/docker.sh"

# ──────────────────────────────────────────────
# 5. WordPress configuration (WP-CLI)
# ──────────────────────────────────────────────
source "$SETUP_DIR/wordpress.sh"

# ──────────────────────────────────────────────
# Cleanup state file — setup succeeded
# ──────────────────────────────────────────────
rm -f "$STATE_FILE"

# ──────────────────────────────────────────────
# Done!
# ──────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "  ${BOLD}║            Setup complete!               ║${NC}"
echo -e "  ${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "    ${BOLD}Theme:${NC}       $PROJECT_NAME"
echo -e "    ${BOLD}Theme dir:${NC}   $THEME_DIR"
echo -e "    ${BOLD}WordPress:${NC}   http://localhost:$WP_PORT"
if [ "${WP_SETUP_MODE:-1}" = "1" ]; then
echo -e "    ${BOLD}Admin:${NC}       http://localhost:$WP_PORT/wp-admin  ${DIM}(${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})${NC}"
fi
echo -e "    ${BOLD}phpMyAdmin:${NC}  http://localhost:$PMA_PORT"
echo ""
echo -e "    ${BOLD}Commands:${NC}"
echo -e "      ${CYAN}$PM run dev${NC}    Start development"
echo -e "      ${CYAN}$PM run build${NC}  Production build"
echo -e "      ${CYAN}$PM run stop${NC}   Stop Docker"
echo -e "      ${CYAN}$PM run reset${NC}  Full reset"
echo ""

# ── Launch dev server ──
exec $PM run dev
