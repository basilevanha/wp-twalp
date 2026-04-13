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
  | head -1 || true)

if [ -n "$RUNNING_PORT" ] && [ "$RUNNING_PORT" != "$WP_PORT" ]; then
  info "WordPress container is on port $RUNNING_PORT but .env wants $WP_PORT — recreating"
  run_with_spinner_sh "Stopping old containers" \
    "cd '$ROOT_DIR/docker' && docker compose --env-file '$ENV_FILE' down"
  run_with_spinner_sh "Recreating Docker containers on port $WP_PORT" \
    "cd '$ROOT_DIR/docker' && docker compose --env-file '$ENV_FILE' up -d --force-recreate"
elif docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ENV_FILE" ps --status running 2>/dev/null | grep -q "wordpress"; then
  success "Docker containers already running"
else
  run_with_spinner_sh "Starting Docker containers" \
    "cd '$ROOT_DIR/docker' && docker compose --env-file '$ENV_FILE' up -d"
fi

# ── Wait for WordPress ──
wait_with_spinner "Waiting for WordPress to be ready" 60 \
  "curl -s -o /dev/null -w '%{http_code}' 'http://localhost:$WP_PORT' | grep -q '200\\|302'"

# ── Initial sync ──
run_with_spinner_sh "Running initial file sync" \
  "cd '$ROOT_DIR' && node bin/sync.js"
