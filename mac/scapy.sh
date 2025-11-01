#!/usr/bin/env bash

###############################################################################
# inbash :: mac/scapy.sh
# ---------------------------------------------------------------------------
# Description : Installs Scapy on macOS using Homebrew (for dependencies) and
#               pip. Optionally enables packet capture capabilities.
# Usage       : ./scapy.sh [-y|--yes] [--pcap]
# Example     : ./scapy.sh --yes --pcap
# Requirements: macOS with Homebrew and Python 3; sudo required for packet capture setup.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

AUTO_APPROVE=0
ENABLE_PCAP=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes   Run without confirmation prompts.
      --pcap  Configure packet capture permissions for current user.
  -h, --help  Show this help message.

Installs Scapy via pip (user-level) after ensuring Homebrew dependencies
(tcpdump, libdnet, libpcap) are present. Packet capture permissions require sudo.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --pcap)
      ENABLE_PCAP=1
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

if ! command -v brew >/dev/null 2>&1; then
  log_error "Homebrew is required. Install it from https://brew.sh/ before proceeding."
  exit 1
fi

if [[ $AUTO_APPROVE -eq 0 ]]; then
  log_warn "Scapy will be installed for the current user (pip install --user)."
  read -r -p "Proceed with dependency installation and pip setup? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Updating Homebrew metadata..."
brew update

log_info "Installing Homebrew dependencies (tcpdump, libdnet, libpcap, python@3)..."
brew install tcpdump libdnet libpcap python@3 || log_warn "Some dependencies may already be installed."

PYTHON_BIN="$(brew --prefix)/bin/python3"
PIP_BIN="$(brew --prefix)/bin/pip3"
if [[ ! -x "$PYTHON_BIN" ]]; then
  log_warn "brew python not found. Falling back to system python3."
  PYTHON_BIN="$(command -v python3)"
  PIP_BIN="$(command -v pip3 || echo "$PYTHON_BIN -m pip")"
fi

log_info "Ensuring pip is up to date..."
"$PYTHON_BIN" -m pip install --upgrade pip --user

log_info "Installing/Upgrading Scapy and scapy-http..."
"$PYTHON_BIN" -m pip install --upgrade scapy scapy-http --user

if [[ $ENABLE_PCAP -eq 1 ]]; then
  if [[ ${EUID:-0} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      log_error "sudo is required to adjust packet capture permissions."
      exit 1
    fi
  else
    SUDO=""
  fi

  log_info "Granting BPF packet capture permissions to current user ($(id -un))."
  $SUDO dseditgroup -o edit -a "$(id -un)" -t user access_bpf || log_warn "Could not add user to access_bpf; you may need to run manually."
  log_info "You may need to log out and back in for BPF group changes to take effect."
fi

log_info "Scapy installation complete. Run it with:"
log_info "  PATH=\"$HOME/Library/Python/3*/bin:$PATH\" scapy"
