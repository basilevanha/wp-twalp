#!/usr/bin/env bash
# setup/helpers.sh — Colors, prompts, utility functions

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

DIM='\033[2m'

info()    { echo -e "  ${CYAN}ℹ${NC}  $1"; }
success() { echo -e "  ${GREEN}✔${NC}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "  ${RED}✖${NC}  $1"; }
header()  { echo -e "\n  ${BOLD}$1${NC}\n"; }

# Standard prompt (2-space indent)
ask() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  if [ -n "$default" ]; then
    read -rp "$(echo -e "  ${BOLD}$prompt${NC} ${DIM}[$default]${NC}: ")" value
    printf -v "$var_name" '%s' "${value:-$default}"
  else
    read -rp "$(echo -e "  ${BOLD}$prompt${NC}: ")" value
    printf -v "$var_name" '%s' "$value"
  fi
}

# Sub-question prompt (4-space indent, for nested questions)
ask_sub() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  if [ -n "$default" ]; then
    read -rp "$(echo -e "    ${BOLD}$prompt${NC} ${DIM}[$default]${NC}: ")" value
    printf -v "$var_name" '%s' "${value:-$default}"
  else
    read -rp "$(echo -e "    ${BOLD}$prompt${NC}: ")" value
    printf -v "$var_name" '%s' "$value"
  fi
}

# Yes/no prompt
ask_yn() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local hint="y/n"
  [ "$default" = "y" ] && hint="Y/n"
  [ "$default" = "n" ] && hint="y/N"
  read -rp "$(echo -e "  ${BOLD}$prompt${NC} ${DIM}[$hint]${NC}: ")" value
  value="${value:-$default}"
  case "$value" in
    [yY]*) eval "$var_name=y" ;;
    *)     eval "$var_name=n" ;;
  esac
}

# Sub yes/no prompt (4-space indent)
ask_sub_yn() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local hint="y/n"
  [ "$default" = "y" ] && hint="Y/n"
  [ "$default" = "n" ] && hint="y/N"
  read -rp "$(echo -e "    ${BOLD}$prompt${NC} ${DIM}[$hint]${NC}: ")" value
  value="${value:-$default}"
  case "$value" in
    [yY]*) eval "$var_name=y" ;;
    *)     eval "$var_name=n" ;;
  esac
}

# Menu choice (consistent format)
choose() {
  local var_name="$1"
  local default="$2"
  shift 2
  local i=1
  for option in "$@"; do
    if [ "$i" -eq "$default" ]; then
      echo -e "    ${BOLD}${i})${NC} ${option} ${DIM}(default)${NC}"
    else
      echo -e "    ${i}) ${option}"
    fi
    i=$((i + 1))
  done
  echo ""
  read -rp "$(echo -e "  ${BOLD}Choose${NC} ${DIM}[$default]${NC}: ")" value
  printf -v "$var_name" '%s' "${value:-$default}"
}

# Sub-menu choice (6-space indent, for nested menus)
choose_sub() {
  local var_name="$1"
  local default="$2"
  shift 2
  local i=1
  for option in "$@"; do
    if [ "$i" -eq "$default" ]; then
      echo -e "      ${BOLD}${i})${NC} ${option} ${DIM}(default)${NC}"
    else
      echo -e "      ${i}) ${option}"
    fi
    i=$((i + 1))
  done
  echo ""
  read -rp "$(echo -e "    ${BOLD}Choose${NC} ${DIM}[$default]${NC}: ")" value
  printf -v "$var_name" '%s' "${value:-$default}"
}

# Portable sed -i (macOS vs GNU)
sedi() {
  sed -i '' "$@" 2>/dev/null || sed -i "$@"
}

# Detect package manager (same approach as create-next-app / create-vite)
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

# Find a free port starting from the given one
find_free_port() {
  local port=$1
  while lsof -i :"$port" &>/dev/null; do
    port=$((port + 1))
  done
  echo "$port"
}
