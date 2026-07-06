#!/usr/bin/env bash

###############################################################################
# inbash :: install-zsh.sh
# ---------------------------------------------------------------------------
# Description : Installs Zsh (if needed), sets it as the default shell
#               (optional), and fetches Oh My Zsh using the official installer.
#               Works on Debian/Ubuntu, Fedora/RHEL, Arch, macOS, and WSL.
# Usage       : ./install-zsh.sh [-y|--yes] [--set-default]
# Example     : ./install-zsh.sh --yes --set-default
# Requirements: curl, and root/sudo for package installation.
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

The script detects your OS and installs Zsh + Oh My Zsh accordingly.
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

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "darwin"
  else
    echo "unknown"
  fi
}

install_zsh_linux() {
  local os_id="$1"
  log_info "Detected Linux distribution: $os_id"

  if command -v apt-get >/dev/null 2>&1; then
    log_info "Installing Zsh via apt..."
    DEBIAN_FRONTEND=noninteractive sudo apt-get update -y
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y zsh
  elif command -v dnf >/dev/null 2>&1; then
    log_info "Installing Zsh via dnf..."
    sudo dnf install -y zsh
  elif command -v yum >/dev/null 2>&1; then
    log_info "Installing Zsh via yum..."
    sudo yum install -y zsh
  elif command -v pacman >/dev/null 2>&1; then
    log_info "Installing Zsh via pacman..."
    sudo pacman -Sy --noconfirm zsh
  elif command -v apk >/dev/null 2>&1; then
    log_info "Installing Zsh via apk..."
    sudo apk add zsh
  elif command -v zypper >/dev/null 2>&1; then
    log_info "Installing Zsh via zypper..."
    sudo zypper install -y zsh
  else
    log_error "No supported package manager found. Install zsh manually."
    exit 1
  fi
}

install_zsh_macos() {
  log_info "Detected macOS."
  if command -v brew >/dev/null 2>&1; then
    log_info "Installing Zsh via Homebrew..."
    brew install zsh
  elif command -v apt-get >/dev/null 2>&1; then
    # WSL on macOS
    install_zsh_linux "wsl"
  else
    log_error "Homebrew not found. Please install Homebrew first: https://brew.sh"
    exit 1
  fi
}

# --- Main ---

if [[ $AUTO_APPROVE -eq 0 ]]; then
  read -r -p "Install Zsh and Oh My Zsh now? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation aborted by user."
      exit 0
      ;;
  esac
fi

if ! command -v zsh >/dev/null 2>&1; then
  log_info "Zsh is not installed. Installing..."

  if [[ $AUTO_APPROVE -eq 0 ]]; then
    echo "This script requires sudo for package installation."
    read -r -p "Proceed? [y/N] " response
    case "$response" in
      [yY][eE][sS]|[yY]) ;;
      *)
        log_warn "Installation aborted by user."
        exit 0
        ;;
    esac
  fi

  local_os="$(detect_os)"
  if [[ "$local_os" == "darwin" ]]; then
    install_zsh_macos
  else
    install_zsh_linux "$local_os"
  fi
else
  log_info "Zsh is already installed: $(command -v zsh)"
fi

# --- Oh My Zsh ---

if [[ -d "$HOME/.oh-my-zsh" ]]; then
  log_info "Oh My Zsh is already installed at $HOME/.oh-my-zsh"
else
  log_info "Downloading Oh My Zsh installer to a secure temporary location..."
  installer_path="$(mktemp -t ohmyzsh-installer-XXXXXX.sh)"

  trap 'rm -f "$installer_path"' EXIT

  ensure_command curl
  curl -fsSL "$OH_MY_ZSH_INSTALLER_URL" -o "$installer_path"
  chmod 700 "$installer_path"

  log_warn "The installer was fetched from $OH_MY_ZSH_INSTALLER_URL"
  log_warn "Review the script at '$installer_path' before proceeding."

  if [[ $AUTO_APPROVE -eq 0 ]]; then
    read -r -p "Run the Oh My Zsh installer now? [y/N] " response
    case "$response" in
      [yY][eE][sS]|[yY]) ;;
      *)
        log_warn "Skipping Oh My Zsh installation as requested."
        exit 0
        ;;
    esac
  fi

  log_info "Running Oh My Zsh installer..."
  RUNZSH="no" CHSH="no" KEEP_ZSHRC="yes" sh "$installer_path"
fi

# --- Set default shell (optional) ---

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
