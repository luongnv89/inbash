#!/usr/bin/env bash

###############################################################################
# inbash :: valgrind.sh
# ---------------------------------------------------------------------------
# Description : Installs Valgrind for detecting memory leaks and data races on
#               Debian/Ubuntu systems.
# Usage       : ./valgrind.sh [-y|--yes]
# Example     : ./valgrind.sh --yes
# Requirements: apt, sudo/root privileges, network connectivity.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

AUTO_APPROVE=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes   Run without confirmation prompts.
  -h, --help  Show this help message.

Installs the Valgrind suite via apt and prints the installed version.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
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
  read -r -p "Install Valgrind now? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Updating apt package index..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y

log_info "Installing Valgrind..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y valgrind

log_info "Cleaning apt cache..."
$SUDO apt-get autoremove -y >/dev/null
$SUDO apt-get autoclean -y >/dev/null

log_info "Valgrind version: $(valgrind --version)"
log_info "Installation complete."