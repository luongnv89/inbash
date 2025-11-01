#!/usr/bin/env bash

###############################################################################
# inbash :: show_ip_login.sh
# ---------------------------------------------------------------------------
# Description : Installs the show_ip network hook to display IP information on
#               the login screen when interfaces come up or go down.
# Usage       : ./show_ip_login.sh [-y|--yes] [--source <path>]
# Example     : ./show_ip_login.sh --yes --source ./show_ip
# Requirements: sudo/root privileges, Debian/Ubuntu network scripts enabled.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEST_IFUP="/etc/network/if-up.d/show_ip"
readonly DEST_IFPOSTDOWN="/etc/network/if-post-down.d/show_ip"
SOURCE_SCRIPT="$(dirname "$0")/show_ip"

AUTO_APPROVE=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes        Run without confirmation prompts.
      --source PATH Path to the show_ip script (default: $SOURCE_SCRIPT).
  -h, --help       Show this help message.

Installs the show_ip hook to both if-up.d and if-post-down.d directories.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --source)
      SOURCE_SCRIPT="$2"
      shift 2
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

if [[ ! -f "$SOURCE_SCRIPT" ]]; then
  log_error "Source script '$SOURCE_SCRIPT' does not exist."
  exit 1
fi

if [[ ${EUID:-0} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    log_error "Root privileges are required. Install sudo or run as root."
    exit 1
  fi
else
  SUDO=""
fi

if [[ $AUTO_APPROVE -eq 0 ]]; then
  log_warn "This script will copy files into /etc/network hooks and may overwrite existing versions."
  read -r -p "Proceed with installation? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Copying show_ip script to $DEST_IFUP"
$SUDO install -m 0755 "$SOURCE_SCRIPT" "$DEST_IFUP"

log_info "Ensuring /etc/network/if-post-down.d exists"
$SUDO install -d -m 0755 "$(dirname "$DEST_IFPOSTDOWN")"

if [[ -L "$DEST_IFPOSTDOWN" || -e "$DEST_IFPOSTDOWN" ]]; then
  log_warn "$DEST_IFPOSTDOWN already exists; replacing with symlink."
  $SUDO rm -rf "$DEST_IFPOSTDOWN"
fi

log_info "Creating symlink from if-post-down.d to show_ip"
$SUDO ln -s "$DEST_IFUP" "$DEST_IFPOSTDOWN"

log_info "Triggering show_ip script to refresh login banner"
$SUDO "$DEST_IFUP"

log_info "Installation complete."