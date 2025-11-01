#!/usr/bin/env bash

###############################################################################
# inbash :: python3-pip.sh
# ---------------------------------------------------------------------------
# Description : Installs python3-pip and configures python/pip alternatives to
#               prioritize Python 3 on Debian/Ubuntu systems.
# Usage       : ./python3-pip.sh [-y|--yes]
# Example     : ./python3-pip.sh --yes
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

Installs python3-pip and updates python/pip alternatives to Python 3.
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
  read -r -p "Install python3-pip and update alternatives now? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Refreshing apt package index..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y

log_info "Installing python3-pip..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y python3-pip

log_info "Configuring update-alternatives for python -> python3"
$SUDO update-alternatives --install /usr/bin/python python /usr/bin/python3 1

log_info "Configuring update-alternatives for pip -> pip3"
$SUDO update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

log_info "Python 3 and pip3 now configured as defaults."