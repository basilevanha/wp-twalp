#!/usr/bin/env bash
# setup/docker.sh — Start Docker containers, wait for WordPress, run initial sync

# ── Start containers ──
# Check the current published port of the running wordpress container (if any)
RUNNING_PORT=$(docker ps \
  --filter "label=com.docker.compose.project=$PROJECT_NAME" \
  --filter "label=com.docker.compose.service=wordpress" \
  --format '{{.Ports}}' 2>/dev/null \
  | grep -oE '(0\.0\.0\.0|:::)?:[0-9]+->80/tcp' \
  | grep -oE ':[0-9]+->' \
  | tr -d ':->' \
  | head -1)

if [ -n "$RUNNING_PORT" ] && [ "$RUNNING_PORT" != "$WP_PORT" ]; then
  info "WordPress container is running on port $RUNNING_PORT but .env wants $WP_PORT — recreating..."
  (cd "$ROOT_DIR/docker" && docker compose --env-file "$ENV_FILE" down)
  (cd "$ROOT_DIR/docker" && docker compose --env-file "$ENV_FILE" up -d --force-recreate)
  success "Docker containers recreated on port $WP_PORT"
elif docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ENV_FILE" ps --status running 2>/dev/null | grep -q "wordpress"; then
  success "Docker containers already running"
else
  info "Starting Docker containers..."
  (cd "$ROOT_DIR/docker" && docker compose --env-file "$ENV_FILE" up -d)
  success "Docker containers started"
fi

# ── Wait for WordPress ──
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
