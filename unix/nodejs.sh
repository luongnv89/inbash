#!/usr/bin/env bash

###############################################################################
# inbash :: nodejs.sh
# ---------------------------------------------------------------------------
# Description : Installs the latest Node.js LTS release on Debian/Ubuntu based
#               systems using the official NodeSource repository.
# Usage       : ./nodejs.sh [-y|--yes] [--remove-repo]
# Example     : ./nodejs.sh --yes
# Requirements: apt, curl, sudo/root privileges, network connectivity.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly NODESOURCE_SETUP_URL="https://deb.nodesource.com/setup_lts.x"

AUTO_APPROVE=0
REMOVE_REPO=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes        Run without confirmation prompts.
      --remove-repo Remove NodeSource repo after installation.
  -h, --help       Show this help message.

Installs Node.js (LTS) and npm using NodeSource packages.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --remove-repo)
      REMOVE_REPO=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Required command '$1' is not available."
    exit 1
  fi
}

ensure_command curl
ensure_command apt-get

if [[ ${EUID:-0} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    log_error "This script requires root privileges or sudo access."
    exit 1
  fi
else
  SUDO=""
fi

temp_setup_script="$(mktemp -t nodesource-setup-XXXXXX.sh)"
trap 'rm -f "$temp_setup_script"' EXIT

log_info "Downloading NodeSource setup script from $NODESOURCE_SETUP_URL..."
curl -fsSL "$NODESOURCE_SETUP_URL" -o "$temp_setup_script"
chmod 700 "$temp_setup_script"

if [[ $AUTO_APPROVE -eq 0 ]]; then
  log_warn "The setup script was saved to $temp_setup_script. Review before proceeding."
  read -r -p "Execute the NodeSource setup script now? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Configuring NodeSource repository..."
DEBIAN_FRONTEND=noninteractive $SUDO bash "$temp_setup_script"

log_info "Updating package index and installing Node.js..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y nodejs

if command -v node >/dev/null 2>&1; then
  log_info "Node.js version: $(node -v)"
else
  log_warn "Node.js command not found after installation."
fi

if command -v npm >/dev/null 2>&1; then
  log_info "npm version: $(npm -v)"
else
  log_warn "npm command not found after installation."
fi

if [[ $REMOVE_REPO -eq 1 ]]; then
  log_info "Removing NodeSource repository list..."
  $SUDO rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.sources 2>/dev/null || true
  log_info "Repository entry removed. Run 'sudo apt-get update' to refresh indexes."
fi

log_info "Node.js installation completed successfully."
