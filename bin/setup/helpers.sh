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

# Interactive arrow-key menu choice
# Usage: choose VAR_NAME DEFAULT_INDEX "Option 1" "Option 2" ...
# Returns the 1-based index of the selected option
choose() {
  _choose_internal "    " "$@"
}

# Sub-menu choice (6-space indent, for nested menus)
choose_sub() {
  _choose_internal "      " "$@"
}

# Internal: interactive selector with arrow keys
# Args: indent var_name default_index option1 option2 ...
_choose_internal() {
  local indent="$1"
  local var_name="$2"
  local selected=$(($3 - 1))  # convert to 0-based
  shift 3
  local options=("$@")
  local count=${#options[@]}
  local key

  # Hide cursor
  tput civis 2>/dev/null

  # Ensure cursor is restored on exit/interrupt
  trap 'tput cnorm 2>/dev/null; trap - RETURN' RETURN

  # Draw initial menu
  local i
  for ((i = 0; i < count; i++)); do
    if [ "$i" -eq "$selected" ]; then
      echo -e "${indent}${CYAN}→${NC} ${BOLD}${options[$i]}${NC}"
    else
      echo -e "${indent}  ${DIM}${options[$i]}${NC}"
    fi
  done

  # Read keys and update
  while true; do
    # Read a single character (raw mode)
    IFS= read -rsn1 key

    # Enter key — confirm selection
    if [ "$key" = "" ]; then
      break
    fi

    # Escape sequence (arrow keys)
    if [ "$key" = $'\x1b' ]; then
      IFS= read -rsn1 key
      if [ "$key" = "[" ]; then
        IFS= read -rsn1 key
        case "$key" in
          A) # Up arrow
            ((selected > 0)) && ((selected--))
            ;;
          B) # Down arrow
            ((selected < count - 1)) && ((selected++))
            ;;
        esac
      fi
    # j/k vim-style navigation
    elif [ "$key" = "j" ]; then
      ((selected < count - 1)) && ((selected++))
    elif [ "$key" = "k" ]; then
      ((selected > 0)) && ((selected--))
    fi

    # Move cursor up to redraw
    printf "\033[%dA" "$count"

    # Redraw menu
    for ((i = 0; i < count; i++)); do
      # Clear line and redraw
      printf "\r\033[K"
      if [ "$i" -eq "$selected" ]; then
        echo -e "${indent}${CYAN}→${NC} ${BOLD}${options[$i]}${NC}"
      else
        echo -e "${indent}  ${DIM}${options[$i]}${NC}"
      fi
    done
  done

  # Show cursor
  tput cnorm 2>/dev/null

  # Return 1-based index
  printf -v "$var_name" '%s' "$((selected + 1))"
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

# Check if a port is used by a Docker container owned by the given compose project
port_used_by_project() {
  local port=$1
  local project=$2
  [ -z "$project" ] && return 1
  docker ps --filter "label=com.docker.compose.project=$project" --format '{{.Ports}}' 2>/dev/null \
    | grep -qE "(^|[^0-9])0\.0\.0\.0:${port}->|(^|[^0-9]):::${port}->"
}

# Check if a port is free (not bound by anything on the host)
port_is_free() {
  local port=$1
  ! lsof -iTCP:"$port" -sTCP:LISTEN &>/dev/null
}

# Find a free port starting from the given one.
# If PROJECT_NAME is set and the port is used by that project's containers,
# reuse it (the running container is ours — we'll restart it with the same port).
find_free_port() {
  local port=$1
  local project="${2:-${PROJECT_NAME:-}}"
  while ! port_is_free "$port"; do
    if port_used_by_project "$port" "$project"; then
      break
    fi
    port=$((port + 1))
  done
  echo "$port"
}
