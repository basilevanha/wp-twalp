#!/usr/bin/env bash

#
# setup.sh — Interactive setup CLI for the WordPress boilerplate
#
# Usage: npm run setup (or bash bin/setup.sh)
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

# ──────────────────────────────────────────────
# Resolve paths
# ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"

# ──────────────────────────────────────────────
# Welcome
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   WordPress Boilerplate — Setup CLI      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ──────────────────────────────────────────────
# 1. Project name
# ──────────────────────────────────────────────
header "1/5 — Project"

ask "Project name (slug, used for theme folder)" "starter-theme" PROJECT_NAME

# Sanitize: lowercase, replace spaces/underscores with dashes, strip non-alphanumeric
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g')
success "Project slug: ${BOLD}$PROJECT_NAME${NC}"

# ──────────────────────────────────────────────
# 2. Environment type
# ──────────────────────────────────────────────
header "2/5 — Environment"

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
    # Docker
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

    # Try to detect WP_HOME from DevKinsta
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

    ask "WordPress URL" "http://localhost" WP_HOME

    success "Environment: Existing WP → $THEME_DIR"
    ;;
  *)
    error "Invalid choice"
    exit 1
    ;;
esac

# ──────────────────────────────────────────────
# 3. Functional options
# ──────────────────────────────────────────────
header "3/5 — Features"

ask_yn "Do you use ACF (Advanced Custom Fields)?" "y" USE_ACF

if [ "$USE_ACF" = "n" ]; then
  info "ACF support will be removed from the theme."
fi

# ──────────────────────────────────────────────
# 4. Write .env
# ──────────────────────────────────────────────
header "4/5 — Configuration"

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

# ──────────────────────────────────────────────
# 4b. Update theme metadata (style.css)
# ──────────────────────────────────────────────
STYLE_CSS="$ROOT_DIR/src/theme/style.css"
if [ -f "$STYLE_CSS" ]; then
  # Replace theme name in style.css
  sed -i '' "s/Theme Name: .*/Theme Name: $PROJECT_NAME/" "$STYLE_CSS" 2>/dev/null || \
  sed -i "s/Theme Name: .*/Theme Name: $PROJECT_NAME/" "$STYLE_CSS"
  success "Updated theme name in style.css"
fi

# ──────────────────────────────────────────────
# 4c. Remove ACF if not needed
# ──────────────────────────────────────────────
if [ "$USE_ACF" = "n" ]; then
  # Remove acf.php include from functions.php
  FUNCTIONS_PHP="$ROOT_DIR/src/theme/functions.php"
  if [ -f "$FUNCTIONS_PHP" ]; then
    sed -i '' "/require_once.*inc\/acf\.php/d" "$FUNCTIONS_PHP" 2>/dev/null || \
    sed -i "/require_once.*inc\/acf\.php/d" "$FUNCTIONS_PHP"
    success "Removed ACF require from functions.php"
  fi

  # Remove acf.php
  if [ -f "$ROOT_DIR/src/theme/inc/acf.php" ]; then
    rm "$ROOT_DIR/src/theme/inc/acf.php"
    success "Removed inc/acf.php"
  fi

  # Remove acf-json directory
  if [ -d "$ROOT_DIR/src/acf-json" ]; then
    rm -rf "$ROOT_DIR/src/acf-json"
    success "Removed src/acf-json/"
  fi

  info "ACF support removed. You can always add it back manually."
fi

# ──────────────────────────────────────────────
# 5. Install dependencies
# ──────────────────────────────────────────────
header "5/5 — Dependencies & Setup"

# Composer
if command -v composer &>/dev/null; then
  info "Installing Composer dependencies (Timber)..."
  (cd "$ROOT_DIR" && composer install --no-interaction --quiet)
  success "Composer dependencies installed"
else
  warn "Composer not found. Please install it and run: composer install"
fi

# npm
if command -v npm &>/dev/null; then
  info "Installing npm dependencies (Vite, etc.)..."
  (cd "$ROOT_DIR" && npm install --silent 2>/dev/null)
  success "npm dependencies installed"
else
  warn "npm not found. Please install Node.js and run: npm install"
fi

# ──────────────────────────────────────────────
# 5b. Docker — start containers
# ──────────────────────────────────────────────
if [ "$USE_DOCKER" = "y" ]; then
  if command -v docker &>/dev/null; then
    info "Starting Docker containers..."
    (cd "$ROOT_DIR/docker" && docker compose up -d)
    success "Docker containers started"

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
  else
    warn "Docker not found. Please install Docker and run: cd docker && docker compose up -d"
  fi
fi

# ──────────────────────────────────────────────
# 5c. Initial sync
# ──────────────────────────────────────────────
info "Running initial file sync..."
(cd "$ROOT_DIR" && node bin/sync.js)
success "Files synced to theme directory"

# ──────────────────────────────────────────────
# 5d. WordPress cleanup & theme activation (WP-CLI)
# ──────────────────────────────────────────────
WP_CLI=""

if [ "$USE_DOCKER" = "y" ]; then
  # Use WP-CLI inside the Docker container
  # Check if wp-cli is available in the container
  if docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec -T wordpress wp --info &>/dev/null 2>&1; then
    WP_CLI="docker compose -f $ROOT_DIR/docker/docker-compose.yml exec -T wordpress wp --allow-root"
  else
    # Install WP-CLI in the container
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
  info "Cleaning up WordPress defaults..."

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
