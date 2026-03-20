#!/usr/bin/env bash
# setup/wordpress.sh — WP-CLI: install WordPress, activate theme, cleanup, homepage

DOCKER_COMPOSE_CMD="docker compose -f $ROOT_DIR/docker/docker-compose.yml --env-file $ENV_FILE"

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

    # Install or import
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

        run_wp option update blogname "$SITE_TITLE" 2>/dev/null || true
        run_wp user update 1 --user_pass="$WP_ADMIN_PASSWORD" --user_login="$WP_ADMIN_USER" --user_email="$WP_ADMIN_EMAIL" 2>/dev/null || true
        run_wp cache flush 2>/dev/null || true
        run_wp rewrite flush 2>/dev/null || true

        success "WordPress restored from dump (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})"
      else
        # Fresh install
        info "Installing WordPress..."
        run_wp core install \
          --url="http://localhost:$WP_PORT" \
          --title="$SITE_TITLE" \
          --admin_user="$WP_ADMIN_USER" \
          --admin_password="$WP_ADMIN_PASSWORD" \
          --admin_email="$WP_ADMIN_EMAIL" \
          --locale="$WP_LOCALE" \
          --skip-email 2>/dev/null && \
          success "WordPress installed (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})" || \
          warn "Could not install WordPress automatically"
      fi
    else
      run_wp option update blogname "$SITE_TITLE" 2>/dev/null && \
        success "Site title set to '$PROJECT_NAME'" || true
    fi

    # Activate theme
    run_wp theme activate "$PROJECT_NAME" 2>/dev/null && \
      success "Theme '$PROJECT_NAME' activated" || \
      warn "Could not activate theme"

    # Clean defaults
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

    # Permalinks
    run_wp rewrite structure '/%postname%/' 2>/dev/null && \
      success "Permalinks set to /%postname%/" || true

    # Timezone
    run_wp option update timezone_string "Europe/Paris" 2>/dev/null && \
      success "Timezone set to Europe/Paris" || true

    # Homepage
    if [ "${WP_HOMEPAGE:-1}" = "1" ]; then
      HOMEPAGE_TITLE="${WP_HOMEPAGE_TITLE:-Home}"
      HOMEPAGE_ID=$(run_wp post create --post_type=page --post_title="$HOMEPAGE_TITLE" --post_status=publish --porcelain 2>/dev/null)
      if [ -n "$HOMEPAGE_ID" ]; then
        run_wp option update show_on_front 'page' 2>/dev/null
        run_wp option update page_on_front "$HOMEPAGE_ID" 2>/dev/null
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
