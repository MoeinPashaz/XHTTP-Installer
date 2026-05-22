#!/usr/bin/env bash
set -euo pipefail

readonly REPO_URL="https://github.com/avacocloud/XHTTP-Installer.git"
readonly TARGET_DIR="/root/XHTTP-Installer"
readonly BRANCH="main"

C_CYAN="\033[1;36m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_RESET="\033[0m"

info(){ echo -e "${C_CYAN}➜${C_RESET} $*"; }
ok(){ echo -e "${C_GREEN}✔${C_RESET} $*"; }
warn(){ echo -e "${C_YELLOW}⚠${C_RESET} $*"; }
fail(){ echo -e "${C_RED}✘${C_RESET} $*"; exit 1; }

[[ $EUID -eq 0 ]] || fail "Run as root"

# ── install git if missing
command -v git &>/dev/null || {
  info "Installing git..."
  apt-get update -qq && apt-get install -y -qq git
}

# ── clone/update with retry
clone_repo() {
  if [[ -d "$TARGET_DIR/.git" ]]; then
    warn "Updating existing installation..."
    git -C "$TARGET_DIR" fetch origin "$BRANCH"
    git -C "$TARGET_DIR" reset --hard "origin/$BRANCH"
  else
    rm -rf "$TARGET_DIR"
    info "Cloning repository..."
    git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
  fi
}

retry() {
  local n=0 max=3
  until [[ $n -ge $max ]]; do
    clone_repo && return 0
    n=$((n+1))
    warn "Retry $n/$max"
    sleep 2
  done
  fail "Failed to clone repo after retries"
}

retry

cd "$TARGET_DIR" || fail "Target directory missing"

# ── detect entry script dynamically
ENTRY=""

if [[ -f "install.sh" ]]; then
  ENTRY="install.sh"
elif [[ -f "Deploy-Ubuntu.sh" ]]; then
  ENTRY="Deploy-Ubuntu.sh"
else
  fail "No installer entry script found"
fi

chmod +x "$ENTRY"

info "Running installer: $ENTRY"
exec bash "$ENTRY" "$@"
