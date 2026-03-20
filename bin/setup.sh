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
    printf -v "$var_name" '%s' "${value:-$default}"
  else
    read -rp "$(echo -e "${BOLD}$prompt${NC}: ")" value
    printf -v "$var_name" '%s' "$value"
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
# Detect package manager (same approach as create-next-app / create-vite)
# Priority: npm_config_user_agent → lock file → npm
# ──────────────────────────────────────────────
detect_pm() {
  local ua="${npm_config_user_agent:-}"
  if [ -n "$ua" ]; then
    case "$ua" in
      pnpm*) echo "pnpm"; return ;;
      yarn*) echo "yarn"; return ;;
      bun*)  echo "bun";  return ;;
    esac
  fi
  if [ -f "$ROOT_DIR/pnpm-lock.yaml" ]; then echo "pnpm"
  elif [ -f "$ROOT_DIR/yarn.lock" ]; then echo "yarn"
  elif [ -f "$ROOT_DIR/bun.lockb" ] || [ -f "$ROOT_DIR/bun.lock" ]; then echo "bun"
  else echo "npm"
  fi
}

PM=$(detect_pm)

# ──────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────
preflight() {
  local errors=0

  if ! command -v node &>/dev/null; then
    error "node is not installed (required for Vite and sync)"
    errors=$((errors + 1))
  fi

  if ! command -v "$PM" &>/dev/null; then
    error "$PM is not installed"
    errors=$((errors + 1))
  fi

  if ! command -v composer &>/dev/null; then
    warn "Composer not found — you will need to install dependencies manually"
  fi

  if ! docker info &>/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker Desktop and re-run setup."
    errors=$((errors + 1))
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
  echo -e "    WP setup:    ${BOLD}$([ "${WP_SETUP_MODE:-1}" = "1" ] && echo "Automatic ($WP_ADMIN_USER)" || echo "Vanilla")${NC}"
  echo -e "    Ports:       ${BOLD}WordPress :$WP_PORT${NC} / ${BOLD}phpMyAdmin :$PMA_PORT${NC}"
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

  # ── 1. Project ──
  header "1/4 — Project"

  ask "Project name (slug, used for theme folder and text domain)" "starter-theme" PROJECT_NAME

  # Sanitize: lowercase, replace spaces/underscores with dashes, strip non-alphanumeric
  PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g')
  success "Project slug: ${BOLD}$PROJECT_NAME${NC}"

  # ── 2. Docker environment ──
  header "2/4 — Docker"

  THEME_DIR="./public/wp-content/themes/$PROJECT_NAME"
  VENDOR_PATH="/var/www/vendor"
  DB_HOST="db"

  # DB name is derived from slug (underscores, prefixed with wp_)
  DB_NAME="wp_$(echo "$PROJECT_NAME" | tr '-' '_')"

  # Check if a Docker volume already exists for this project
  VOLUME_NAME="${PROJECT_NAME}_db_data"
  if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    warn "A database volume ${BOLD}${VOLUME_NAME}${NC} already exists for this project."
    echo ""
    echo "  1) Use existing database (keep data)"
    echo "  2) Create a new project name"
    echo "  3) Delete old database and start fresh"
    echo ""
    read -rp "$(echo -e "${BOLD}Choose${NC} [1]: ")" DB_CHOICE
    DB_CHOICE="${DB_CHOICE:-1}"
    case "$DB_CHOICE" in
      2)
        info "Re-run setup with a different project name."
        exit 0
        ;;
      3)
        info "Removing old volume ${VOLUME_NAME}..."
        docker volume rm "$VOLUME_NAME" 2>/dev/null && success "Volume removed" || warn "Could not remove volume (containers may still be using it)"
        ;;
      *)
        info "Reusing existing database"
        ;;
    esac
  fi

  # Find available ports (auto-increment like Vite)
  find_free_port() {
    local port=$1
    while lsof -i :"$port" &>/dev/null; do
      port=$((port + 1))
    done
    echo "$port"
  }

  WP_PORT=$(find_free_port 8080)
  PMA_PORT=$(find_free_port $((WP_PORT + 1)))

  if [ "$WP_PORT" != "8080" ]; then
    warn "Port 8080 is busy, using ${BOLD}${WP_PORT}${NC} for WordPress"
  fi
  if [ "$PMA_PORT" != "8081" ]; then
    warn "Port 8081 is busy, using ${BOLD}${PMA_PORT}${NC} for phpMyAdmin"
  fi

  WP_HOME="http://localhost:$WP_PORT"

  # DB user/password with smart defaults (user can override by typing)
  DB_PASSWORD_DEFAULT=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 16 2>/dev/null) || true
  [ -z "$DB_PASSWORD_DEFAULT" ] && DB_PASSWORD_DEFAULT="wp_$(date +%s)"
  ask "Database user" "$DB_NAME" DB_USER
  ask "Database password" "$DB_PASSWORD_DEFAULT" DB_PASSWORD

  # Check for existing database dumps
  IMPORT_DUMP=""
  DUMP_FILES=()
  if [ -d "$ROOT_DIR/database" ]; then
    while IFS= read -r -d '' f; do
      DUMP_FILES+=("$f")
    done < <(find "$ROOT_DIR/database" -name "dump-*.sql" -print0 2>/dev/null | sort -rz)
  fi

  if [ "${#DUMP_FILES[@]}" -gt 0 ]; then
    echo ""
    info "Database dumps found:"
    echo ""
    dump_i=1
    for f in "${DUMP_FILES[@]}"; do
      fname=$(basename "$f")
      fsize=$(du -h "$f" | cut -f1 | tr -d ' ')
      if [ "$dump_i" -eq 1 ]; then
        echo -e "  ${CYAN}→${NC} ${BOLD}${dump_i})${NC} ${fname} (${fsize})"
      else
        echo -e "    ${dump_i}) ${fname} (${fsize})"
      fi
      dump_i=$((dump_i + 1))
    done
    echo -e "    ${dump_i}) Fresh install (empty database)"
    echo ""
    read -rp "$(echo -e "${BOLD}Choose${NC} [$dump_i]: ")" DUMP_CHOICE
    DUMP_CHOICE="${DUMP_CHOICE:-$dump_i}"

    if [ "$DUMP_CHOICE" -lt "$dump_i" ] 2>/dev/null; then
      idx=$((DUMP_CHOICE - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#DUMP_FILES[@]}" ]; then
        IMPORT_DUMP="${DUMP_FILES[$idx]}"
        success "Will import: $(basename "$IMPORT_DUMP")"
      fi
    else
      success "Fresh install selected"
    fi
  fi

  success "Docker (WordPress: :${WP_PORT}, phpMyAdmin: :${PMA_PORT})"

  # ── 3. WordPress configuration ──
  header "3/4 — WordPress"

  echo "  1) Automatic setup via CLI (recommended)"
  echo "  2) Vanilla (manual setup via browser)"
  echo ""
  read -rp "$(echo -e "${BOLD}Choose${NC} [1]: ")" WP_SETUP_MODE
  WP_SETUP_MODE="${WP_SETUP_MODE:-1}"

  WP_ADMIN_USER=""
  WP_ADMIN_PASSWORD=""
  WP_ADMIN_EMAIL=""
  WP_LOCALE=""
  WP_CLEAN_DEFAULTS=""

  if [ "$WP_SETUP_MODE" = "1" ]; then
    echo ""
    ask "Admin username" "admin" WP_ADMIN_USER
    ask "Admin password" "admin" WP_ADMIN_PASSWORD
    ask "Admin email" "admin@example.com" WP_ADMIN_EMAIL
    ask "Language (e.g. fr_FR, en_US, nl_NL)" "fr_FR" WP_LOCALE
    ask_yn "Clean default themes & plugins?" "y" WP_CLEAN_DEFAULTS
    success "Automatic setup selected"
  else
    success "Vanilla mode — configure WordPress at http://localhost:$WP_PORT after setup"
  fi

  # ── 4. Functional options ──
  header "4/4 — Features"

  ask_yn "Do you use ACF (Advanced Custom Fields)?" "y" USE_ACF

  if [ "$USE_ACF" = "n" ]; then
    info "ACF support will be removed from the theme."
  fi

  # ── Save state for resume ──
  # Use declare -p to safely serialize variables (handles special chars in values)
  {
    for _var in PROJECT_NAME THEME_DIR WP_HOME WP_PORT PMA_PORT DB_NAME DB_USER DB_PASSWORD \
                WP_SETUP_MODE WP_ADMIN_USER WP_ADMIN_PASSWORD WP_ADMIN_EMAIL WP_LOCALE \
                WP_CLEAN_DEFAULTS USE_ACF IMPORT_DUMP; do
      declare -p "$_var" 2>/dev/null || true
    done
  } > "$STATE_FILE"

fi # end SKIP_QUESTIONS

# ──────────────────────────────────────────────
# 4. Configuration
# ──────────────────────────────────────────────
header "Configuration & Setup"

# ── Write .env (with confirmation if exists) ──
WRITE_ENV="y"
if [ -f "$ENV_FILE" ]; then
  ask_yn ".env already exists. Overwrite?" "y" WRITE_ENV
fi

WP_PORT="${WP_PORT:-8080}"
PMA_PORT="${PMA_PORT:-8081}"

if [ "$WRITE_ENV" = "y" ]; then
  cat > "$ENV_FILE" <<EOF
# Project
PROJECT_NAME=$PROJECT_NAME
THEME_DIR=$THEME_DIR

# Docker
COMPOSE_PROJECT_NAME=$PROJECT_NAME
WP_PORT=$WP_PORT
PMA_PORT=$PMA_PORT

# WordPress
WP_HOME=http://localhost:$WP_PORT
WP_SITEURL=http://localhost:$WP_PORT

# Database
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=db

# Vendor path inside Docker container
VENDOR_PATH=/var/www/vendor

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
    sed -i '' "s|'starter-theme'|'$PROJECT_NAME'|g" {} + 2>/dev/null || \
  find "$ROOT_DIR/src/theme" -name "*.php" -exec \
    sed -i "s|'starter-theme'|'$PROJECT_NAME'|g" {} +

  find "$ROOT_DIR/src/templates" -name "*.twig" -exec \
    sed -i '' "s|'starter-theme'|'$PROJECT_NAME'|g" {} + 2>/dev/null || \
  find "$ROOT_DIR/src/templates" -name "*.twig" -exec \
    sed -i "s|'starter-theme'|'$PROJECT_NAME'|g" {} +

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

if command -v "$PM" &>/dev/null; then
  info "Installing dependencies via ${BOLD}$PM${NC}..."
  (cd "$ROOT_DIR" && "$PM" install --silent 2>/dev/null) || (cd "$ROOT_DIR" && "$PM" install 2>/dev/null)
  success "Dependencies installed ($PM)"
else
  warn "$PM not found. Run manually: $PM install"
fi

# ── Docker — start containers ──
if docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ENV_FILE" ps --status running 2>/dev/null | grep -q "wordpress"; then
  success "Docker containers already running"
else
  info "Starting Docker containers..."
  (cd "$ROOT_DIR/docker" && docker compose --env-file "$ENV_FILE" up -d)
  success "Docker containers started"
fi

info "Waiting for WordPress to be ready..."
MAX_WAIT=60
ELAPSED=0
while ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:$WP_PORT" | grep -q "200\|302"; do
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

# ── Initial sync ──
info "Running initial file sync..."
(cd "$ROOT_DIR" && node bin/sync.js)
success "Files synced to theme directory"

# ── WordPress configuration (WP-CLI) ──
DOCKER_COMPOSE_CMD="docker compose -f $ROOT_DIR/docker/docker-compose.yml --env-file $ENV_FILE"

# Wrapper function for WP-CLI
run_wp() {
  $DOCKER_COMPOSE_CMD exec -T wordpress wp --allow-root "$@"
}

if [ "${WP_SETUP_MODE:-1}" = "1" ]; then
  # ── Automatic setup ──
  HAS_WP_CLI="n"

  if $DOCKER_COMPOSE_CMD exec -T wordpress wp --allow-root --info &>/dev/null 2>&1; then
    HAS_WP_CLI="y"
  else
    info "Installing WP-CLI in Docker container..."
    $DOCKER_COMPOSE_CMD exec -T wordpress bash -c \
      "curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp" 2>/dev/null && \
    HAS_WP_CLI="y" || \
    warn "Could not install WP-CLI in Docker container."
  fi

  if [ "$HAS_WP_CLI" = "y" ]; then
    info "Configuring WordPress..."

    # Install WordPress if not already installed
    if ! run_wp core is-installed 2>/dev/null; then

      if [ -n "${IMPORT_DUMP:-}" ] && [ -f "${IMPORT_DUMP:-}" ]; then
        info "Importing database from $(basename "$IMPORT_DUMP")..."
        $DOCKER_COMPOSE_CMD exec -T db sh -c \
          'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" 2>/dev/null' \
          < "$IMPORT_DUMP" && \
          success "Database imported" || \
          { warn "Could not import database. Starting fresh."; IMPORT_DUMP=""; }
      fi

      if [ -n "${IMPORT_DUMP:-}" ] && [ -f "${IMPORT_DUMP:-}" ]; then
        # DB was imported — detect old URL and search-replace
        OLD_URL=$(run_wp option get siteurl 2>/dev/null || true)
        NEW_URL="http://localhost:$WP_PORT"

        if [ -n "$OLD_URL" ] && [ "$OLD_URL" != "$NEW_URL" ]; then
          info "Replacing URLs: $OLD_URL → $NEW_URL"
          run_wp search-replace "$OLD_URL" "$NEW_URL" --all-tables --skip-columns=guid 2>/dev/null && \
            success "URLs updated" || warn "Could not update URLs"
        fi

        run_wp option update blogname "$PROJECT_NAME" 2>/dev/null || true
        run_wp user update 1 --user_pass="$WP_ADMIN_PASSWORD" --user_login="$WP_ADMIN_USER" --user_email="$WP_ADMIN_EMAIL" 2>/dev/null || true
        run_wp cache flush 2>/dev/null || true
        run_wp rewrite flush 2>/dev/null || true

        success "WordPress restored from dump (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})"
      else
        # Fresh install
        info "Installing WordPress..."
        run_wp core install \
          --url="http://localhost:$WP_PORT" \
          --title="$PROJECT_NAME" \
          --admin_user="$WP_ADMIN_USER" \
          --admin_password="$WP_ADMIN_PASSWORD" \
          --admin_email="$WP_ADMIN_EMAIL" \
          --locale="$WP_LOCALE" \
          --skip-email 2>/dev/null && \
          success "WordPress installed (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})" || \
          warn "Could not install WordPress automatically"
      fi
    else
      run_wp option update blogname "$PROJECT_NAME" 2>/dev/null && \
        success "Site title set to '$PROJECT_NAME'" || true
    fi

    # Activate our theme
    run_wp theme activate "$PROJECT_NAME" 2>/dev/null && \
      success "Theme '$PROJECT_NAME' activated" || \
      warn "Could not activate theme"

    # Clean defaults (if requested)
    if [ "${WP_CLEAN_DEFAULTS:-y}" = "y" ]; then
      run_wp plugin delete hello 2>/dev/null && success "Removed Hello Dolly" || true
      run_wp plugin delete akismet 2>/dev/null && success "Removed Akismet" || true

      for theme in twentytwentythree twentytwentyfour twentytwentyfive; do
        run_wp theme delete "$theme" 2>/dev/null && success "Removed $theme" || true
      done

      run_wp post delete 1 --force 2>/dev/null && success "Removed sample post" || true
      run_wp post delete 2 --force 2>/dev/null && success "Removed sample page" || true
      run_wp comment delete 1 --force 2>/dev/null && success "Removed sample comment" || true
    fi

    # Set pretty permalinks
    run_wp rewrite structure '/%postname%/' 2>/dev/null && \
      success "Permalinks set to /%postname%/" || true

    # Set timezone
    run_wp option update timezone_string "Europe/Paris" 2>/dev/null && \
      success "Timezone set to Europe/Paris" || true

  else
    warn "WP-CLI not available. Configure WordPress manually at http://localhost:$WP_PORT"
  fi

else
  # ── Vanilla mode ──
  info "Vanilla mode — skipping WordPress configuration."
  info "Open ${BOLD}http://localhost:$WP_PORT${NC} to complete the WordPress installation."
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
echo -e "  ${BOLD}WordPress:${NC}   http://localhost:$WP_PORT"
if [ "${WP_SETUP_MODE:-1}" = "1" ]; then
echo -e "  ${BOLD}Admin:${NC}       http://localhost:$WP_PORT/wp-admin  (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})"
fi
echo -e "  ${BOLD}phpMyAdmin:${NC}  http://localhost:$PMA_PORT"
echo ""
echo -e "  ${BOLD}Commands:${NC}"
echo -e "    ${CYAN}npm run dev${NC}    Start development (Vite + file sync)"
echo -e "    ${CYAN}npm run build${NC}  Build for production"
echo -e "    ${CYAN}npm run stop${NC}   Stop Docker containers"
echo -e "    ${CYAN}npm run reset${NC}  Clean everything (Docker volumes + public/ + .env)"
echo ""

# ── Launch dev server ──
exec npm run dev
