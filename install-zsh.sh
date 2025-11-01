#!/usr/bin/env bash

###############################################################################
# inbash :: install-zsh.sh
# ---------------------------------------------------------------------------
# Description : Installs Zsh, sets it as the default shell (optional) and
#               fetches Oh My Zsh using the official installer.
# Usage       : ./install-zsh.sh [-y|--yes] [--set-default]
# Example     : ./install-zsh.sh --yes --set-default
# Requirements: Debian/Ubuntu based system with apt, curl, and sudo or root.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly OH_MY_ZSH_INSTALLER_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

AUTO_APPROVE=0
SET_DEFAULT_SHELL=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes         Run non-interactively (auto approve).
      --set-default Switch current user to Zsh after installation.
  -h, --help        Show this help message.

The script installs Zsh and Oh My Zsh using apt and the upstream installer.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --set-default)
      SET_DEFAULT_SHELL=1
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

ensure_command apt-get
ensure_command curl

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

if [[ $AUTO_APPROVE -eq 0 ]]; then
  read -r -p "Install Zsh and Oh My Zsh now? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      log_warn "Installation aborted by user."
      exit 0
      ;;
  esac
fi

log_info "Updating apt package index..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y

log_info "Installing Zsh..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y zsh

log_info "Downloading Oh My Zsh installer to a secure temporary location..."
installer_path="$(mktemp -t ohmyzsh-installer-XXXXXX.sh)"

trap 'rm -f "$installer_path"' EXIT

curl -fsSL "$OH_MY_ZSH_INSTALLER_URL" -o "$installer_path"
chmod 700 "$installer_path"

log_warn "The installer was fetched from $OH_MY_ZSH_INSTALLER_URL"
log_warn "Review the script at '$installer_path' before proceeding."

if [[ $AUTO_APPROVE -eq 0 ]]; then
  read -r -p "Run the Oh My Zsh installer now? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      log_warn "Skipping Oh My Zsh installation as requested."
      exit 0
      ;;
  esac
fi

log_info "Running Oh My Zsh installer..."
RUNZSH="no" CHSH="no" KEEP_ZSHRC="yes" sh "$installer_path"

if [[ $SET_DEFAULT_SHELL -eq 1 ]]; then
  if chsh -s "$(command -v zsh)" "$USER"; then
    log_info "Default shell switched to Zsh for user $USER. Logout and login to apply."
  else
    log_warn "Failed to change default shell. You can run: chsh -s \"$(command -v zsh)\""
  fi
else
  log_info "Keeping current default shell. Use 'chsh -s \\$(command -v zsh)' to change later."
fi

log_info "Zsh installation complete."
