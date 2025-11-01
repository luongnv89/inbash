#!/usr/bin/env bash

###############################################################################
# inbash :: mac/docker.sh
# ---------------------------------------------------------------------------
# Description : Installs Docker Desktop on macOS using Homebrew and offers an
#               option to launch the app after installation.
# Usage       : ./docker.sh [-y|--yes] [--start]
# Example     : ./docker.sh --yes --start
# Requirements: macOS 12+, Homebrew, virtualization enabled (Apple HVF or Rosetta).
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

AUTO_APPROVE=0
START_AFTER_INSTALL=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes   Run without confirmation prompts.
      --start Launch Docker Desktop after installation completes.
  -h, --help  Show this help message.

The script installs Docker Desktop via Homebrew (cask 'docker') and prints
post-install guidance. You may be prompted by macOS for permissions.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --start)
      START_AFTER_INSTALL=1
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
  log_warn "Docker Desktop is a large install (~600 MB) and may request elevated permissions."
  read -r -p "Proceed with installation via Homebrew cask? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Updating Homebrew formulae..."
brew update

if brew list --cask docker >/dev/null 2>&1; then
  log_info "Docker Desktop cask already installed. Running 'brew upgrade --cask docker'."
  brew upgrade --cask docker || log_warn "Upgrade failed; existing install left untouched."
else
  log_info "Installing Docker Desktop via Homebrew cask..."
  brew install --cask docker
fi

log_info "Docker Desktop installed. You may need to grant virtualization permissions on first launch."
log_info "If prompted, allow the helper to access system extensions and restart as required."

if [[ $START_AFTER_INSTALL -eq 1 ]]; then
  if open -Ra "Docker"; then
    log_info "Launch request sent to Docker Desktop. Wait for the whale icon in the menu bar."
  else
    log_warn "Unable to start Docker Desktop automatically. Launch it manually from /Applications."
  fi
fi

log_info "Verify the CLI with 'docker --version' after Docker Desktop finishes initial setup."
