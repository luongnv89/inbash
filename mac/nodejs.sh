#!/usr/bin/env bash

###############################################################################
# inbash :: mac/nodejs.sh
# ---------------------------------------------------------------------------
# Description : Installs Node.js on macOS using Homebrew with optional formula
#               selection (e.g., node, node@20) and post-install guidance.
# Usage       : ./nodejs.sh [-y|--yes] [--formula <brew-formula>] [--force-link]
# Example     : ./nodejs.sh --yes --formula node@20 --force-link
# Requirements: macOS with Homebrew installed; developer tools for building.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_FORMULA="node"

AUTO_APPROVE=0
FORCE_LINK=0
FORMULA="$DEFAULT_FORMULA"

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes             Run without confirmation prompts.
      --formula NAME    Homebrew formula to install (default: $DEFAULT_FORMULA).
      --force-link      Force 'brew link' for versioned formulae (node@20, etc.).
  -h, --help            Show this help message.

Examples:
  $SCRIPT_NAME --yes                     # Install latest stable Node.js
  $SCRIPT_NAME --formula node@20 --force-link  # Install LTS and link it as default
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --formula)
      FORMULA="$2"
      shift 2
      ;;
    --force-link)
      FORCE_LINK=1
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
  log_warn "Node.js installation may overwrite existing node/npm binaries."
  read -r -p "Install Homebrew formula '$FORMULA'? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Updating Homebrew tap metadata..."
brew update

if brew list "$FORMULA" >/dev/null 2>&1; then
  log_info "Formula '$FORMULA' already installed. Attempting upgrade."
  brew upgrade "$FORMULA" || log_warn "Upgrade failed; leaving existing installation."
else
  log_info "Installing '$FORMULA' via Homebrew..."
  brew install "$FORMULA"
fi

if [[ $FORCE_LINK -eq 1 ]]; then
  log_info "Linking '$FORMULA' so node/npm are available on PATH..."
  brew link "$FORMULA" --overwrite --force
fi

log_info "Node.js installation complete. Versions:"
if command -v node >/dev/null 2>&1; then
  log_info "node: $(node -v)"
else
  log_warn "'node' not found on PATH. Run 'brew info $FORMULA' for linking instructions."
fi

if command -v npm >/dev/null 2>&1; then
  log_info "npm: $(npm -v)"
fi

if command -v corepack >/dev/null 2>&1; then
  log_info "Enable Corepack-managed package managers with: corepack enable"
fi

log_info "Consider installing pnpm/yarn via 'corepack enable' or Homebrew as needed."
