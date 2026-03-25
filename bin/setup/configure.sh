#!/usr/bin/env bash
# setup/configure.sh — Generate .env, update theme metadata, remove ACF, install dependencies

echo ""
echo -e "  ${DIM}──────────────────────────────────────────${NC}"
echo ""

# ── Write .env ──
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
if [ "$PROJECT_NAME" != "wp-twalp" ]; then
  info "Replacing text domain 'wp-twalp' → '$PROJECT_NAME'..."
  find "$ROOT_DIR/src/theme" -name "*.php" -exec \
    sed -i '' "s|'wp-twalp'|'$PROJECT_NAME'|g" {} + 2>/dev/null || \
  find "$ROOT_DIR/src/theme" -name "*.php" -exec \
    sed -i "s|'wp-twalp'|'$PROJECT_NAME'|g" {} +

  find "$ROOT_DIR/src/templates" -name "*.twig" -exec \
    sed -i '' "s|'wp-twalp'|'$PROJECT_NAME'|g" {} + 2>/dev/null || \
  find "$ROOT_DIR/src/templates" -name "*.twig" -exec \
    sed -i "s|'wp-twalp'|'$PROJECT_NAME'|g" {} +

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
