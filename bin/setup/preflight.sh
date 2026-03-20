#!/usr/bin/env bash
# setup/preflight.sh — Pre-flight checks

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
