#!/usr/bin/env bash

#
# setup.sh — Interactive setup CLI for the WordPress boilerplate
#
# Usage: npm run setup (or bash bin/setup.sh)
#
# Features:
#   - Pre-flight checks (node, npm, composer, Docker)
#   - Saves answers to .setup-state for resume after failure
#   - Idempotent operations (safe to re-run)
#   - Replaces text domain in all theme files
#

set -euo pipefail

# ──────────────────────────────────────────────
# Colors & helpers
# ──────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✔${NC}  $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✖${NC}  $1"; }
header()  { echo -e "\n${BOLD}$1${NC}\n"; }

ask() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  if [ -n "$default" ]; then
    read -rp "$(echo -e "${BOLD}$prompt${NC} [$default]: ")" value
    eval "$var_name='${value:-$default}'"
  else
    read -rp "$(echo -e "${BOLD}$prompt${NC}: ")" value
    eval "$var_name='$value'"
  fi
}

ask_yn() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local hint="y/n"
  [ "$default" = "y" ] && hint="Y/n"
  [ "$default" = "n" ] && hint="y/N"
  read -rp "$(echo -e "${BOLD}$prompt${NC} [$hint]: ")" value
  value="${value:-$default}"
  case "$value" in
    [yY]*) eval "$var_name=y" ;;
    *)     eval "$var_name=n" ;;
  esac
}

# Portable sed -i (macOS vs GNU)
sedi() {
  sed -i '' "$@" 2>/dev/null || sed -i "$@"
}

# ──────────────────────────────────────────────
# Resolve paths
# ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
STATE_FILE="$ROOT_DIR/.setup-state"

# ──────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────
preflight() {
  local errors=0

  if ! command -v node &>/dev/null; then
    error "node is not installed (required for Vite and sync)"
    errors=$((errors + 1))
  fi

  if ! command -v npm &>/dev/null; then
    error "npm is not installed"
    errors=$((errors + 1))
  fi

  if ! command -v composer &>/dev/null; then
    warn "Composer not found — you will need to install dependencies manually"
  fi

  if [ "$errors" -gt 0 ]; then
    error "Pre-flight checks failed. Please fix the issues above and re-run."
    exit 1
  fi
}

preflight

# ──────────────────────────────────────────────
# Error trap — keep state file on failure
# ──────────────────────────────────────────────
on_error() {
  local exit_code=$?
  if [ $exit_code -ne 0 ] && [ -f "$STATE_FILE" ]; then
    echo ""
    warn "Setup interrupted (exit code: $exit_code)."
    info "Your answers have been saved. Re-run ${BOLD}npm run setup${NC} to resume."
  fi
}
trap on_error EXIT

# ──────────────────────────────────────────────
# Welcome
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   WordPress Boilerplate — Setup CLI      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
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
  echo -e "    Project:     ${BOLD}$PROJECT_NAME${NC}"
  echo -e "    Environment: ${BOLD}$ENV_CHOICE${NC} (1=Docker, 2=DevKinsta, 3=Existing WP)"
  echo -e "    Theme dir:   ${BOLD}$THEME_DIR${NC}"
  echo -e "    ACF:         ${BOLD}$USE_ACF${NC}"
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
# Questions (skipped if resuming)
# ──────────────────────────────────────────────
if [ "$SKIP_QUESTIONS" != "y" ]; then

  # ── 1. Project name ──
  header "1/4 — Project"

  ask "Project name (slug, used for theme folder and text domain)" "starter-theme" PROJECT_NAME

  # Sanitize: lowercase, replace spaces/underscores with dashes, strip non-alphanumeric
  PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g')
  success "Project slug: ${BOLD}$PROJECT_NAME${NC}"

  # ── 2. Environment type ──
  header "2/4 — Environment"

  echo "  1) Docker (included docker-compose, recommended)"
  echo "  2) DevKinsta (local site already created)"
  echo "  3) Existing WordPress installation"
  echo ""
  read -rp "$(echo -e "${BOLD}Choose your environment${NC} [1]: ")" ENV_CHOICE
  ENV_CHOICE="${ENV_CHOICE:-1}"

  THEME_DIR=""
  WP_HOME=""
  VENDOR_PATH=""
  DB_NAME="wordpress"
  DB_USER="wordpress"
  DB_PASSWORD="wordpress"
  DB_HOST="db"
  USE_DOCKER="n"

  case "$ENV_CHOICE" in
    1)
      # Check Docker before going further
      if ! docker info &>/dev/null 2>&1; then
        error "Docker daemon is not running. Please start Docker Desktop and re-run setup."
        exit 1
      fi

      USE_DOCKER="y"
      THEME_DIR="./public/wp-content/themes/$PROJECT_NAME"
      WP_HOME="http://localhost:8080"
      VENDOR_PATH="/var/www/vendor"

      ask "Database name" "wordpress" DB_NAME
      ask "Database user" "wordpress" DB_USER
      ask "Database password" "wordpress" DB_PASSWORD
      DB_HOST="db"

      success "Environment: Docker"
      ;;
    2)
      # DevKinsta
      ask "Path to your DevKinsta site root (e.g. ~/DevKinsta/public/my-site)" "" DEVKINSTA_PATH

      # Expand ~ to $HOME
      DEVKINSTA_PATH="${DEVKINSTA_PATH/#\~/$HOME}"

      if [ ! -d "$DEVKINSTA_PATH" ]; then
        error "Directory not found: $DEVKINSTA_PATH"
        exit 1
      fi

      THEME_DIR="$DEVKINSTA_PATH/wp-content/themes/$PROJECT_NAME"
      VENDOR_PATH=""
      DB_HOST="localhost"
      USE_DOCKER="n"
      WP_HOME=""

      ask "WordPress URL" "http://localhost" WP_HOME

      success "Environment: DevKinsta → $THEME_DIR"
      ;;
    3)
      # Existing WP
      ask "Path to your WordPress installation (the folder with wp-content/)" "" WP_PATH
      WP_PATH="${WP_PATH/#\~/$HOME}"

      if [ ! -d "$WP_PATH/wp-content" ]; then
        error "wp-content/ not found in: $WP_PATH"
        exit 1
      fi

      THEME_DIR="$WP_PATH/wp-content/themes/$PROJECT_NAME"
      VENDOR_PATH=""
      DB_HOST="localhost"
      USE_DOCKER="n"
      WP_HOME=""

      ask "WordPress URL" "http://localhost" WP_HOME

      success "Environment: Existing WP → $THEME_DIR"
      ;;
    *)
      error "Invalid choice"
      exit 1
      ;;
  esac

  # ── 3. Functional options ──
  header "3/4 — Features"

  ask_yn "Do you use ACF (Advanced Custom Fields)?" "y" USE_ACF

  if [ "$USE_ACF" = "n" ]; then
    info "ACF support will be removed from the theme."
  fi

  # ── Save state for resume ──
  cat > "$STATE_FILE" <<EOF
PROJECT_NAME="$PROJECT_NAME"
ENV_CHOICE="$ENV_CHOICE"
USE_DOCKER="$USE_DOCKER"
THEME_DIR="$THEME_DIR"
WP_HOME="$WP_HOME"
VENDOR_PATH="$VENDOR_PATH"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASSWORD="$DB_PASSWORD"
DB_HOST="$DB_HOST"
USE_ACF="$USE_ACF"
EOF

fi # end SKIP_QUESTIONS

# ──────────────────────────────────────────────
# 4. Configuration
# ──────────────────────────────────────────────
header "4/4 — Configuration & Setup"

# ── Write .env (with confirmation if exists) ──
WRITE_ENV="y"
if [ -f "$ENV_FILE" ]; then
  ask_yn ".env already exists. Overwrite?" "y" WRITE_ENV
fi

if [ "$WRITE_ENV" = "y" ]; then
  cat > "$ENV_FILE" <<EOF
# Project
PROJECT_NAME=$PROJECT_NAME
THEME_DIR=$THEME_DIR

# WordPress
WP_HOME=$WP_HOME
WP_SITEURL=$WP_HOME

# Database
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=$DB_HOST

# Vendor path inside Docker container (leave empty for local/DevKinsta)
VENDOR_PATH=$VENDOR_PATH

# Vite
VITE_DEV_SERVER=http://localhost:5173
EOF
  success "Generated .env"
else
  info "Keeping existing .env"
fi

# ── Update theme metadata (style.css) ──
STYLE_CSS="$ROOT_DIR/src/theme/style.css"
if [ -f "$STYLE_CSS" ]; then
  sedi "s/Theme Name: .*/Theme Name: $PROJECT_NAME/" "$STYLE_CSS"
  sedi "s/Text Domain: .*/Text Domain: $PROJECT_NAME/" "$STYLE_CSS"
  success "Updated theme name and text domain in style.css"
fi

# ── Replace text domain in all PHP and Twig files ──
if [ "$PROJECT_NAME" != "starter-theme" ]; then
  info "Replacing text domain 'starter-theme' → '$PROJECT_NAME'..."
  find "$ROOT_DIR/src/theme" -name "*.php" -exec \
    sed -i '' "s/'starter-theme'/'$PROJECT_NAME'/g" {} + 2>/dev/null || \
  find "$ROOT_DIR/src/theme" -name "*.php" -exec \
    sed -i "s/'starter-theme'/'$PROJECT_NAME'/g" {} +

  find "$ROOT_DIR/src/templates" -name "*.twig" -exec \
    sed -i '' "s/'starter-theme'/'$PROJECT_NAME'/g" {} + 2>/dev/null || \
  find "$ROOT_DIR/src/templates" -name "*.twig" -exec \
    sed -i "s/'starter-theme'/'$PROJECT_NAME'/g" {} +

  success "Text domain updated to '$PROJECT_NAME'"
fi

# ── Remove ACF if not needed ──
if [ "$USE_ACF" = "n" ]; then
  FUNCTIONS_PHP="$ROOT_DIR/src/theme/functions.php"
  if [ -f "$FUNCTIONS_PHP" ] && grep -q "inc/acf.php" "$FUNCTIONS_PHP"; then
    sedi "/require_once.*inc\/acf\.php/d" "$FUNCTIONS_PHP"
    success "Removed ACF require from functions.php"
  fi

  if [ -f "$ROOT_DIR/src/theme/inc/acf.php" ]; then
    rm "$ROOT_DIR/src/theme/inc/acf.php"
    success "Removed inc/acf.php"
  fi

  if [ -d "$ROOT_DIR/src/acf-json" ]; then
    rm -rf "$ROOT_DIR/src/acf-json"
    success "Removed src/acf-json/"
  fi

  info "ACF support removed."
fi

# ── Install dependencies ──
if command -v composer &>/dev/null; then
  info "Installing Composer dependencies (Timber)..."
  (cd "$ROOT_DIR" && composer install --no-interaction --quiet)
  success "Composer dependencies installed"
else
  warn "Composer not found. Run manually: composer install"
fi

if command -v npm &>/dev/null; then
  info "Installing npm dependencies (Vite, etc.)..."
  (cd "$ROOT_DIR" && npm install --silent 2>/dev/null)
  success "npm dependencies installed"
else
  warn "npm not found. Run manually: npm install"
fi

# ── Docker — start containers ──
if [ "$USE_DOCKER" = "y" ]; then
  # Check again in case Docker was stopped between questions and now
  if ! docker info &>/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker Desktop and re-run setup."
    exit 1
  fi

  # Check if containers are already running
  if docker compose -f "$ROOT_DIR/docker/docker-compose.yml" ps --status running 2>/dev/null | grep -q "wordpress"; then
    success "Docker containers already running"
  else
    info "Starting Docker containers..."
    (cd "$ROOT_DIR/docker" && docker compose up -d)
    success "Docker containers started"
  fi

  info "Waiting for WordPress to be ready..."
  MAX_WAIT=60
  ELAPSED=0
  while ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080" | grep -q "200\|302"; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
      warn "WordPress not responding yet. It may still be starting up."
      break
    fi
  done
  if [ "$ELAPSED" -lt "$MAX_WAIT" ]; then
    success "WordPress is running"
  fi
fi

# ── Initial sync ──
info "Running initial file sync..."
(cd "$ROOT_DIR" && node bin/sync.js)
success "Files synced to theme directory"

# ── WordPress cleanup & theme activation (WP-CLI) ──
WP_CLI=""

if [ "$USE_DOCKER" = "y" ]; then
  if docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec -T wordpress wp --info &>/dev/null 2>&1; then
    WP_CLI="docker compose -f $ROOT_DIR/docker/docker-compose.yml exec -T wordpress wp --allow-root"
  else
    info "Installing WP-CLI in Docker container..."
    docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec -T wordpress bash -c \
      "curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp" 2>/dev/null && \
    WP_CLI="docker compose -f $ROOT_DIR/docker/docker-compose.yml exec -T wordpress wp --allow-root" || \
    warn "Could not install WP-CLI in Docker container."
  fi
elif command -v wp &>/dev/null; then
  WP_CLI="wp --path=$(echo "$THEME_DIR" | sed 's|/wp-content/themes/.*||')"
fi

if [ -n "$WP_CLI" ]; then
  info "Configuring WordPress..."

  # Set site title
  $WP_CLI option update blogname "$PROJECT_NAME" 2>/dev/null && \
    success "Site title set to '$PROJECT_NAME'" || true

  # Activate our theme
  $WP_CLI theme activate "$PROJECT_NAME" 2>/dev/null && \
    success "Theme '$PROJECT_NAME' activated" || \
    warn "Could not activate theme (WordPress may not be fully installed yet)"

  # Delete default plugins
  $WP_CLI plugin delete hello 2>/dev/null && success "Removed Hello Dolly" || true
  $WP_CLI plugin delete akismet 2>/dev/null && success "Removed Akismet" || true

  # Delete default themes (keep ours)
  for theme in twentytwentythree twentytwentyfour twentytwentyfive; do
    $WP_CLI theme delete "$theme" 2>/dev/null && success "Removed $theme" || true
  done

  # Delete sample content
  $WP_CLI post delete 1 --force 2>/dev/null && success "Removed sample post" || true
  $WP_CLI post delete 2 --force 2>/dev/null && success "Removed sample page" || true
  $WP_CLI comment delete 1 --force 2>/dev/null && success "Removed sample comment" || true

  # Set pretty permalinks
  $WP_CLI rewrite structure '/%postname%/' 2>/dev/null && \
    success "Permalinks set to /%postname%/" || true

  # Set timezone
  $WP_CLI option update timezone_string "Europe/Paris" 2>/dev/null && \
    success "Timezone set to Europe/Paris" || true

else
  warn "WP-CLI not available. You can clean up WordPress manually or install WP-CLI."
  info "  → Delete plugins: Hello Dolly, Akismet"
  info "  → Delete unused default themes"
  info "  → Activate theme: $PROJECT_NAME"
  info "  → Set permalinks to /%postname%/"
fi

# ──────────────────────────────────────────────
# Cleanup state file — setup succeeded
# ──────────────────────────────────────────────
rm -f "$STATE_FILE"

# ──────────────────────────────────────────────
# Done!
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║            Setup complete!                ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Theme:${NC}       $PROJECT_NAME"
echo -e "  ${BOLD}Theme dir:${NC}   $THEME_DIR"
if [ "$USE_DOCKER" = "y" ]; then
echo -e "  ${BOLD}WordPress:${NC}   http://localhost:8080"
echo -e "  ${BOLD}phpMyAdmin:${NC}  http://localhost:8081"
else
echo -e "  ${BOLD}WordPress:${NC}   $WP_HOME"
fi
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    ${CYAN}npm run dev${NC}    Start development (Vite + file sync)"
echo -e "    ${CYAN}npm run build${NC}  Build for production"
echo ""
