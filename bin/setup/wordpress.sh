#!/usr/bin/env bash
# setup/wordpress.sh — WP-CLI: install WordPress, activate theme, cleanup, homepage

docker_compose() {
  docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ENV_FILE" "$@"
}

# Run a WP-CLI command silently. Captures stdout+stderr; on success returns 0
# with nothing printed. On failure, the caller can decide whether to surface
# the captured output via $WP_LAST_ERROR.
WP_LAST_ERROR=""
run_wp() {
  local log
  log=$(mktemp)
  if docker_compose exec -T wordpress wp --allow-root "$@" >"$log" 2>&1; then
    rm -f "$log"
    WP_LAST_ERROR=""
    return 0
  else
    local rc=$?
    WP_LAST_ERROR=$(cat "$log")
    rm -f "$log"
    return $rc
  fi
}

# Run a WP-CLI step and report via ✔ or ⚠ (with captured log on failure).
# Usage: wp_step "Label" wp-cli args...
wp_step() {
  local label="$1"
  shift
  if run_wp "$@"; then
    success "$label"
  else
    warn "$label — failed"
    if [ -n "$WP_LAST_ERROR" ]; then
      echo ""
      sed 's/^/       /' <<<"$WP_LAST_ERROR"
      echo ""
    fi
  fi
}

if [ "${WP_SETUP_MODE:-1}" = "1" ]; then
  # ── Automatic setup ──
  HAS_WP_CLI="n"

  if docker_compose exec -T wordpress wp --allow-root --info &>/dev/null; then
    HAS_WP_CLI="y"
  else
    if run_with_spinner_sh "Installing WP-CLI in Docker container" \
        "docker compose -f '$ROOT_DIR/docker/docker-compose.yml' --env-file '$ENV_FILE' exec -T wordpress bash -c 'curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp'"; then
      HAS_WP_CLI="y"
    else
      warn "Could not install WP-CLI in Docker container."
    fi
  fi

  if [ "$HAS_WP_CLI" = "y" ]; then

    # ── Install or import ──
    if ! run_wp core is-installed; then

      if [ -n "${IMPORT_DUMP:-}" ] && [ -f "${IMPORT_DUMP:-}" ]; then
        if run_with_spinner_sh "Importing database from $(basename "$IMPORT_DUMP")" \
            "docker compose -f '$ROOT_DIR/docker/docker-compose.yml' --env-file '$ENV_FILE' exec -T db sh -c 'mysql -u\"\$MYSQL_USER\" -p\"\$MYSQL_PASSWORD\" \"\$MYSQL_DATABASE\"' < '$IMPORT_DUMP'"; then
          :
        else
          warn "Could not import database. Starting fresh."
          IMPORT_DUMP=""
        fi
      fi

      if [ -n "${IMPORT_DUMP:-}" ] && [ -f "${IMPORT_DUMP:-}" ]; then
        # DB was imported — detect old URL and search-replace
        OLD_URL=$(docker_compose exec -T wordpress wp --allow-root option get siteurl 2>/dev/null || true)
        NEW_URL="http://localhost:$WP_PORT"

        if [ -n "$OLD_URL" ] && [ "$OLD_URL" != "$NEW_URL" ]; then
          wp_step "URLs updated ($OLD_URL → $NEW_URL)" \
            search-replace "$OLD_URL" "$NEW_URL" --all-tables --skip-columns=guid
        fi

        run_wp option update blogname "$SITE_TITLE" || true
        run_wp user update 1 --user_pass="$WP_ADMIN_PASSWORD" --user_login="$WP_ADMIN_USER" --user_email="$WP_ADMIN_EMAIL" || true
        run_wp cache flush || true
        run_wp rewrite flush || true

        success "WordPress restored from dump (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})"
      else
        # Fresh install — this is a 3-10s operation, worth a spinner
        if run_with_spinner_sh "Installing WordPress" \
            "docker compose -f '$ROOT_DIR/docker/docker-compose.yml' --env-file '$ENV_FILE' exec -T wordpress wp --allow-root core install --url='http://localhost:$WP_PORT' --title='$SITE_TITLE' --admin_user='$WP_ADMIN_USER' --admin_password='$WP_ADMIN_PASSWORD' --admin_email='$WP_ADMIN_EMAIL' --locale='$WP_LOCALE' --skip-email"; then
          info "Admin: ${BOLD}${WP_ADMIN_USER}${NC} / ${BOLD}${WP_ADMIN_PASSWORD}${NC}"
        fi
      fi
    else
      wp_step "Site title set to '$PROJECT_NAME'" option update blogname "$SITE_TITLE"
    fi

    # ── Activate theme ──
    wp_step "Theme '$PROJECT_NAME' activated" theme activate "$PROJECT_NAME"

    # ── Install ACF ──
    if [ "${USE_ACF:-y}" = "y" ]; then
      if run_wp plugin is-installed advanced-custom-fields; then
        wp_step "ACF activated" plugin activate advanced-custom-fields
      else
        run_with_spinner_sh "Installing ACF plugin" \
          "docker compose -f '$ROOT_DIR/docker/docker-compose.yml' --env-file '$ENV_FILE' exec -T wordpress wp --allow-root plugin install advanced-custom-fields --activate" || \
          warn "Could not install ACF plugin"
      fi
    fi

    # ── Clean defaults (grouped spinner) ──
    if [ "${WP_CLEAN_DEFAULTS:-y}" = "y" ]; then
      run_with_spinner_sh "Cleaning WordPress defaults" \
        "docker compose -f '$ROOT_DIR/docker/docker-compose.yml' --env-file '$ENV_FILE' exec -T wordpress bash -c '
          wp --allow-root plugin delete hello akismet 2>/dev/null
          wp --allow-root theme delete twentytwentythree twentytwentyfour twentytwentyfive 2>/dev/null
          wp --allow-root post delete 1 2 --force 2>/dev/null
          wp --allow-root comment delete 1 --force 2>/dev/null
          true
        '"
    fi

    # ── Permalinks, timezone, homepage ──
    wp_step "Permalinks set to /%postname%/" rewrite structure '/%postname%/'
    wp_step "Timezone set to Europe/Paris" option update timezone_string "Europe/Paris"

    if [ "${WP_HOMEPAGE:-1}" = "1" ]; then
      HOMEPAGE_TITLE="${WP_HOMEPAGE_TITLE:-Home}"
      HOMEPAGE_ID=$(docker_compose exec -T wordpress wp --allow-root post create --post_type=page --post_title="$HOMEPAGE_TITLE" --post_status=publish --porcelain 2>/dev/null | tr -d '\r')
      if [ -n "$HOMEPAGE_ID" ]; then
        run_wp option update show_on_front 'page' || true
        run_wp option update page_on_front "$HOMEPAGE_ID" || true
        success "Homepage set to static page '$HOMEPAGE_TITLE' (ID: $HOMEPAGE_ID)"
      else
        warn "Could not create homepage"
      fi
    fi

  else
    warn "WP-CLI not available. Configure WordPress manually at http://localhost:$WP_PORT"
  fi

else
  # ── Vanilla mode ──
  info "Vanilla mode — skipping WordPress configuration."
  info "Open ${BOLD}http://localhost:$WP_PORT${NC} to complete the WordPress installation."
fi
