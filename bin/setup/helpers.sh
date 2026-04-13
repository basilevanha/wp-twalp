#!/usr/bin/env bash
# setup/helpers.sh — Colors, prompts, utility functions

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

DIM='\033[2m'

# Locales offered in the language picker. Empty code = "Other (custom)".
LOCALES_LABELS=(
  "Français (fr_FR)"
  "English — US (en_US)"
  "Nederlands (nl_NL)"
  "Deutsch (de_DE)"
  "Español (es_ES)"
  "Other (custom code)"
)
LOCALES_CODES=("fr_FR" "en_US" "nl_NL" "de_DE" "es_ES" "")

info()    { echo -e "     ${CYAN}ℹ${NC}  $1"; }
success() { echo -e "     ${GREEN}✔${NC}  $1"; }
warn()    { echo -e "     ${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "     ${RED}✖${NC}  $1"; }
header()  { echo -e "\n  ${BOLD}$1${NC}\n"; }

# Run a command with a Braille spinner. On success, prints a green ✔ with the label.
# On failure, prints a red ✖ and forwards the command's exit code.
# Usage: run_with_spinner "Label while running" -- command arg1 arg2...
run_with_spinner() {
  local label="$1"
  shift
  # Drop leading "--" separator if present
  [ "${1:-}" = "--" ] && shift

  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local log
  log=$(mktemp)

  # Start command in background, capture both stdout and stderr
  ( "$@" >"$log" 2>&1 ) &
  local pid=$!

  # Hide cursor while spinning
  tput civis 2>/dev/null

  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r     ${CYAN}%s${NC}  %s" "${frames[i]}" "$label"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.08
  done

  wait "$pid"
  local rc=$?

  # Clear line + restore cursor
  printf "\r\033[K"
  tput cnorm 2>/dev/null

  if [ $rc -eq 0 ]; then
    echo -e "     ${GREEN}✔${NC}  $label"
  else
    echo -e "     ${RED}✖${NC}  $label"
    if [ -s "$log" ]; then
      echo ""
      sed 's/^/       /' "$log"
      echo ""
    fi
  fi
  rm -f "$log"
  return $rc
}

# Same as run_with_spinner but the command is given as a single shell string.
# Useful when you need subshells, pipes, or env vars in the command.
run_with_spinner_sh() {
  local label="$1"
  local cmd="$2"
  run_with_spinner "$label" -- bash -c "$cmd"
}

# Poll a shell predicate with a spinner + "(Xs / Ys)" counter until it succeeds
# or the timeout is reached. Returns 0 on success, 1 on timeout.
# Usage: wait_with_spinner "Label" MAX_SECONDS "shell predicate to test"
wait_with_spinner() {
  local label="$1"
  local max="$2"
  local predicate="$3"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local elapsed=0
  local i=0

  tput civis 2>/dev/null
  while ! eval "$predicate" >/dev/null 2>&1; do
    # Spin 10 frames (≈1 second) between predicate checks
    local f
    for ((f = 0; f < 10; f++)); do
      printf "\r     ${CYAN}%s${NC}  %s  ${DIM}(%ds / %ds)${NC}\033[K" \
        "${frames[i]}" "$label" "$elapsed" "$max"
      i=$(( (i + 1) % ${#frames[@]} ))
      sleep 0.1
    done
    elapsed=$((elapsed + 1))
    if [ "$elapsed" -ge "$max" ]; then
      printf "\r\033[K"
      tput cnorm 2>/dev/null
      echo -e "     ${YELLOW}⚠${NC}  $label — timed out after ${max}s"
      return 1
    fi
  done
  printf "\r\033[K"
  tput cnorm 2>/dev/null
  echo -e "     ${GREEN}✔${NC}  $label"
  return 0
}

# Chapter header: full-width rules + emoji + title + step counter + description.
# Usage: chapter "emoji" "Title" "One-line description"
# Reads SETUP_CURRENT_CHAPTER / SETUP_TOTAL_CHAPTERS and auto-increments.
chapter() {
  local emoji="$1"
  local title="$2"
  local description="$3"
  local current="${SETUP_CURRENT_CHAPTER:-1}"
  local total="${SETUP_TOTAL_CHAPTERS:-3}"
  local rule="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e "  ${DIM}${rule}${NC}"
  echo -e "   ${emoji}  ${BOLD}${title}${NC}   ${DIM}· Step ${current} of ${total}${NC}"
  echo -e "  ${DIM}${rule}${NC}"
  echo ""
  if [ -n "$description" ]; then
    echo -e "     ${DIM}${description}${NC}"
    echo ""
  fi
  SETUP_CURRENT_CHAPTER=$((current + 1))
}

# Standard prompt. Optional 4th arg = label width for column alignment.
ask() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local width="${4:-0}"
  local label
  printf -v label "%-${width}s" "$prompt"
  if [ -n "$default" ]; then
    read -rp "$(echo -e "     ${BOLD}${label}${NC}  ${DIM}[$default]${NC}: ")" value
    printf -v "$var_name" '%s' "${value:-$default}"
  else
    read -rp "$(echo -e "     ${BOLD}${label}${NC}: ")" value
    printf -v "$var_name" '%s' "$value"
  fi
}

# Sub-question prompt (nested under a choose/menu).
ask_sub() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local width="${4:-0}"
  local label
  printf -v label "%-${width}s" "$prompt"
  if [ -n "$default" ]; then
    read -rp "$(echo -e "       ${BOLD}${label}${NC}  ${DIM}[$default]${NC}: ")" value
    printf -v "$var_name" '%s' "${value:-$default}"
  else
    read -rp "$(echo -e "       ${BOLD}${label}${NC}: ")" value
    printf -v "$var_name" '%s' "$value"
  fi
}

# Yes/no arrow-key menu. Optional 4th arg = dim hint printed next to the label.
choose_yn() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local hint="${4:-}"
  local default_idx=1
  [ "$default" = "n" ] && default_idx=2
  if [ -n "$hint" ]; then
    echo -e "     ${BOLD}$prompt${NC}  ${DIM}· $hint${NC}"
  else
    echo -e "     ${BOLD}$prompt${NC}"
  fi
  local _idx
  choose _idx "$default_idx" "Yes" "No"
  if [ "$_idx" = "1" ]; then
    printf -v "$var_name" 'y'
  else
    printf -v "$var_name" 'n'
  fi
}

# Sub yes/no arrow-key menu (nested under a parent choose/menu).
choose_sub_yn() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local hint="${4:-}"
  local default_idx=1
  [ "$default" = "n" ] && default_idx=2
  if [ -n "$hint" ]; then
    echo -e "       ${BOLD}$prompt${NC}  ${DIM}· $hint${NC}"
  else
    echo -e "       ${BOLD}$prompt${NC}"
  fi
  local _idx
  choose_sub _idx "$default_idx" "Yes" "No"
  if [ "$_idx" = "1" ]; then
    printf -v "$var_name" 'y'
  else
    printf -v "$var_name" 'n'
  fi
}

# Interactive arrow-key menu choice
# Usage: choose VAR_NAME DEFAULT_INDEX "Option 1" "Option 2" ...
# Returns the 1-based index of the selected option
choose() {
  _choose_internal "     " "$@"
}

# Sub-menu choice (nested, deeper indent)
choose_sub() {
  _choose_internal "       " "$@"
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
