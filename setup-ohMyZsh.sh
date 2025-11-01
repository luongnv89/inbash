#!/usr/bin/env bash

###############################################################################
# inbash :: setup-ohMyZsh.sh
# ---------------------------------------------------------------------------
# Description : Installs recommended Oh My Zsh community plugins and copies a
#               curated .zshrc configuration for the current user.
# Usage       : ./setup-ohMyZsh.sh [-y|--yes] [--config <path>]
# Example     : ./setup-ohMyZsh.sh --yes --config ./zshrc-config
# Requirements: git, curl (for Oh My Zsh), existing Oh My Zsh installation.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_CONFIG_SOURCE="$(dirname "$0")/zshrc-config"
readonly DEFAULT_PLUGINS=(
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-completions"
)

AUTO_APPROVE=0
CONFIG_SOURCE="$DEFAULT_CONFIG_SOURCE"

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes          Run without confirmation prompts.
      --config PATH  Path to custom zshrc config (default: $DEFAULT_CONFIG_SOURCE).
  -h, --help         Show this help message.

This script assumes Oh My Zsh is installed at \${ZSH:-~/.oh-my-zsh}.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --config)
      CONFIG_SOURCE="$2"
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

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Required command '$1' is not available."
    exit 1
  fi
}

ensure_command git

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-"$ZSH_DIR/custom"}"

if [[ ! -d "$ZSH_DIR" ]]; then
  log_error "Oh My Zsh not found at '$ZSH_DIR'. Please install it first."
  exit 1
fi

if [[ ! -f "$CONFIG_SOURCE" ]]; then
  log_error "Config file '$CONFIG_SOURCE' does not exist."
  exit 1
fi

if [[ $AUTO_APPROVE -eq 0 ]]; then
  log_info "This script will clone plugins into '$ZSH_CUSTOM_DIR/plugins'."
  read -r -p "Continue? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Operation cancelled by user."
      exit 0
      ;;
  esac
fi

mkdir -p "$ZSH_CUSTOM_DIR/plugins"

clone_plugin() {
  local repo="$1"
  local destination="$ZSH_CUSTOM_DIR/plugins/${repo##*/}"

  if [[ -d "$destination/.git" ]]; then
    log_info "Updating existing plugin '$repo'."
    git -C "$destination" pull --ff-only
  elif [[ -d "$destination" ]]; then
    log_warn "Directory '$destination' exists without git metadata. Skipping."
  else
    log_info "Cloning plugin '$repo' into '$destination'."
    git clone "https://github.com/$repo.git" "$destination"
  fi
}

for plugin_repo in "${DEFAULT_PLUGINS[@]}"; do
  clone_plugin "$plugin_repo"
done

backup_path="$HOME/.zshrc.$(date +%Y%m%d%H%M%S).bak"
if [[ -f "$HOME/.zshrc" ]]; then
  log_info "Backing up existing ~/.zshrc to '$backup_path'."
  cp "$HOME/.zshrc" "$backup_path"
fi

log_info "Copying config from '$CONFIG_SOURCE' to '$HOME/.zshrc'."
cp "$CONFIG_SOURCE" "$HOME/.zshrc"

log_info "Oh My Zsh plugins setup complete. Open a new terminal session to use them."
