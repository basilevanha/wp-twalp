#!/usr/bin/env bash
# setup/questions.sh — Interactive questions (3 steps)

if [ "$SKIP_QUESTIONS" != "y" ]; then

  SETUP_CURRENT_CHAPTER=1
  SETUP_TOTAL_CHAPTERS=3

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # 1. Project
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  chapter "📦" "Project" "Name your site and set up the local database."

  ask "Site name"    "Wp twalp" SITE_TITLE 12

  # Derive slug from site name
  DEFAULT_SLUG=$(echo "$SITE_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g')
  ask "Project slug" "$DEFAULT_SLUG" PROJECT_NAME 12
  PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g')

  THEME_DIR="./public/wp-content/themes/$PROJECT_NAME"
  VENDOR_PATH="/var/www/vendor"
  DB_HOST="db"
  DB_NAME="wp_$(echo "$PROJECT_NAME" | tr '-' '_')"

  # Check if a Docker volume already exists
  VOLUME_NAME="${PROJECT_NAME}_db_data"
  if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    echo ""
    warn "A database volume ${BOLD}${VOLUME_NAME}${NC} already exists."
    echo ""
    choose DB_CHOICE 1 \
      "Use existing database (keep data)" \
      "Choose a different project name" \
      "Delete old database and start fresh"
    case "$DB_CHOICE" in
      2)
        info "Re-run setup with a different project name."
        exit 0
        ;;
      3)
        info "Removing old volume ${VOLUME_NAME}..."
        docker volume rm "$VOLUME_NAME" 2>/dev/null && success "Volume removed" || warn "Could not remove volume"
        ;;
      *)
        info "Reusing existing database"
        ;;
    esac
  fi

  # Reuse ports from existing .env if present (setup re-run on same project)
  EXISTING_WP_PORT=""
  EXISTING_PMA_PORT=""
  if [ -f "$ENV_FILE" ]; then
    EXISTING_WP_PORT=$(grep -E '^WP_PORT=' "$ENV_FILE" | tail -1 | cut -d= -f2-)
    EXISTING_PMA_PORT=$(grep -E '^PMA_PORT=' "$ENV_FILE" | tail -1 | cut -d= -f2-)
  fi

  # WP_PORT: prefer existing if free OR held by our own project containers
  if [ -n "$EXISTING_WP_PORT" ] && { port_is_free "$EXISTING_WP_PORT" || port_used_by_project "$EXISTING_WP_PORT" "$PROJECT_NAME"; }; then
    WP_PORT="$EXISTING_WP_PORT"
  else
    WP_PORT=$(find_free_port 8080 "$PROJECT_NAME")
  fi

  # PMA_PORT: same logic, search from existing or WP_PORT+1
  if [ -n "$EXISTING_PMA_PORT" ] && [ "$EXISTING_PMA_PORT" != "$WP_PORT" ] && { port_is_free "$EXISTING_PMA_PORT" || port_used_by_project "$EXISTING_PMA_PORT" "$PROJECT_NAME"; }; then
    PMA_PORT="$EXISTING_PMA_PORT"
  else
    PMA_PORT=$(find_free_port $((WP_PORT + 1)) "$PROJECT_NAME")
  fi

  WP_HOME="http://localhost:$WP_PORT"

  [ "$WP_PORT" != "8080" ] && warn "Port 8080 busy → using ${BOLD}${WP_PORT}${NC}"
  [ "$PMA_PORT" != "8081" ] && warn "Port 8081 busy → using ${BOLD}${PMA_PORT}${NC}"

  # DB credentials
  DB_PASSWORD_DEFAULT=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 16 2>/dev/null) || true
  [ -z "$DB_PASSWORD_DEFAULT" ] && DB_PASSWORD_DEFAULT="wp_$(date +%s)"
  ask "DB user"     "$DB_NAME"            DB_USER     12
  ask "DB password" "$DB_PASSWORD_DEFAULT" DB_PASSWORD 12

  # Check for existing dumps
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

    # Build option labels with file size
    DUMP_LABELS=()
    for f in "${DUMP_FILES[@]}"; do
      fname=$(basename "$f")
      fsize=$(du -h "$f" | cut -f1 | tr -d ' ')
      DUMP_LABELS+=("${fname} (${fsize})")
    done
    DUMP_LABELS+=("Fresh install (empty database)")

    # Default to last option (fresh install)
    choose DUMP_CHOICE ${#DUMP_LABELS[@]} "${DUMP_LABELS[@]}"

    if [ "$DUMP_CHOICE" -lt "${#DUMP_LABELS[@]}" ] 2>/dev/null; then
      idx=$((DUMP_CHOICE - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#DUMP_FILES[@]}" ]; then
        IMPORT_DUMP="${DUMP_FILES[$idx]}"
        success "Will import: $(basename "$IMPORT_DUMP")"
      fi
    fi
  fi

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # 2. WordPress
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  chapter "🚀" "WordPress" "Install WordPress, configure the admin user and homepage."

  choose WP_SETUP_MODE 1 \
    "Automatic setup via CLI (recommended)" \
    "Vanilla (manual setup via browser)"

  WP_ADMIN_USER=""
  WP_ADMIN_PASSWORD=""
  WP_ADMIN_EMAIL=""
  WP_LOCALE=""
  WP_CLEAN_DEFAULTS=""
  WP_HOMEPAGE=""
  WP_HOMEPAGE_TITLE=""

  if [ "$WP_SETUP_MODE" = "1" ]; then
    echo ""
    ask_sub "Admin username" "admin"             WP_ADMIN_USER     14
    ask_sub "Admin password" "admin"             WP_ADMIN_PASSWORD 14
    ask_sub "Admin email"    "admin@example.com" WP_ADMIN_EMAIL    14

    echo ""
    echo -e "       ${BOLD}Language${NC}"
    choose_sub _locale_idx 1 "${LOCALES_LABELS[@]}"
    if [ "$_locale_idx" = "${#LOCALES_LABELS[@]}" ]; then
      ask_sub "Locale code" "fr_FR" WP_LOCALE 14
    else
      WP_LOCALE="${LOCALES_CODES[$((_locale_idx - 1))]}"
    fi
    unset _locale_idx

    echo ""
    choose_sub_yn "Clean defaults?" "y" WP_CLEAN_DEFAULTS \
      "removes Hello Dolly, Akismet, Twenty* themes and sample content"

    echo ""
    echo -e "       ${BOLD}Homepage${NC}"
    choose_sub WP_HOMEPAGE 1 \
      "Static page (recommended)" \
      "Latest posts"

    if [ "$WP_HOMEPAGE" = "1" ]; then
      ask_sub "Page title" "Home" WP_HOMEPAGE_TITLE 14
    fi
  else
    info "Configure WordPress manually at ${BOLD}http://localhost:$WP_PORT${NC}"
  fi

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # 3. Plugins
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  chapter "🧩" "Plugins" "Pick the WordPress plugins your theme should ship with."

  choose_yn "ACF (Advanced Custom Fields)" "y" USE_ACF \
    "custom fields with JSON sync for git versioning"
  if [ "$USE_ACF" = "n" ]; then
    info "ACF will be removed from the theme."
  fi

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Save state for resume
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  {
    for _var in SITE_TITLE PROJECT_NAME THEME_DIR WP_HOME WP_PORT PMA_PORT DB_NAME DB_USER DB_PASSWORD \
                WP_SETUP_MODE WP_ADMIN_USER WP_ADMIN_PASSWORD WP_ADMIN_EMAIL WP_LOCALE \
                WP_CLEAN_DEFAULTS WP_HOMEPAGE WP_HOMEPAGE_TITLE USE_ACF IMPORT_DUMP; do
      declare -p "$_var" 2>/dev/null || true
    done
  } > "$STATE_FILE"

fi # end SKIP_QUESTIONS
