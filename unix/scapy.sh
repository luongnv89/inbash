#!/usr/bin/env bash

###############################################################################
# inbash :: scapy.sh
# ---------------------------------------------------------------------------
# Description : Installs Scapy and prerequisites for packet crafting/sniffing on
#               Debian/Ubuntu systems using Python 3.
# Usage       : ./scapy.sh [-y|--yes]
# Example     : ./scapy.sh --yes
# Requirements: apt, pip3, sudo/root privileges, network connectivity.
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

Installs Scapy (Python 3) and useful system dependencies.
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
  read -r -p "Install Scapy and dependencies now? [y/N] " response
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

log_info "Installing system dependencies..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y \
  software-properties-common build-essential tcpdump gnuplot \
  python3 python3-pip python3-numpy python3-crypto python3-gnupg

log_info "Installing Scapy via pip3..."
$SUDO python3 -m pip install --upgrade pip
$SUDO python3 -m pip install --upgrade scapy scapy-http

log_info "Scapy installation complete. Run 'sudo scapy' to get started."
