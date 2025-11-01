#!/usr/bin/env bash

###############################################################################
# inbash :: mac/python-pip-uv.sh
# ---------------------------------------------------------------------------
# Description : Installs Python 3 via Homebrew, ensures pip is up to date, and
#               installs the uv package manager on macOS.
# Usage       : ./python-pip-uv.sh [-y|--yes] [--python-formula <name>]
# Example     : ./python-pip-uv.sh --yes --python-formula python@3.12
# Requirements: macOS with Homebrew installed; developer tools for building.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_PYTHON_FORMULA="python@3.12"

AUTO_APPROVE=0
PYTHON_FORMULA="$DEFAULT_PYTHON_FORMULA"

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes                Run without confirmation prompts.
      --python-formula NAME  Homebrew formula to install (default: $DEFAULT_PYTHON_FORMULA).
  -h, --help               Show this help message.

Installs/updates Homebrew Python, refreshes pip/setuptools/wheel, and installs
uv via Homebrew. Prints PATH guidance for the user-level Python bin directory.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --python-formula)
      PYTHON_FORMULA="$2"
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

if ! command -v brew >/dev/null 2>&1; then
  log_error "Homebrew is required. Install it from https://brew.sh/ before proceeding."
  exit 1
fi

if [[ $AUTO_APPROVE -eq 0 ]]; then
  log_warn "Python installation can overwrite existing python3/pip3 binaries."
  read -r -p "Install Homebrew formula '$PYTHON_FORMULA' and uv? [y/N] " response
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

if brew list "$PYTHON_FORMULA" >/dev/null 2>&1; then
  log_info "Formula '$PYTHON_FORMULA' already installed. Attempting upgrade."
  brew upgrade "$PYTHON_FORMULA" || log_warn "Upgrade failed; using existing installation."
else
  log_info "Installing '$PYTHON_FORMULA' via Homebrew..."
  brew install "$PYTHON_FORMULA"
fi

PYTHON_BIN="$(brew --prefix "$PYTHON_FORMULA")/bin/python3"
if [[ ! -x "$PYTHON_BIN" ]]; then
  log_warn "Unable to locate python3 for formula '$PYTHON_FORMULA'. Falling back to system python3."
  PYTHON_BIN="$(command -v python3)"
fi

log_info "Ensuring pip, setuptools, and wheel are available..."
"$PYTHON_BIN" -m ensurepip --upgrade || log_warn "ensurepip failed; pip may already be present."
"$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel

log_info "Installing uv via Homebrew..."
if brew list uv >/dev/null 2>&1; then
  brew upgrade uv || log_warn "uv upgrade failed; existing version remains."
else
  brew install uv
fi

log_info "Python version: $('"$PYTHON_BIN"' -V)"
log_info "pip version   : $('"$PYTHON_BIN"' -m pip --version)"
log_info "uv version    : $(uv --version 2>/dev/null || echo 'uv not on PATH yet')"

USER_BIN="$HOME/Library/Python/$("$PYTHON_BIN" -c 'import sys; print("{}".format(".".join(map(str, sys.version_info[:2]))))')/bin"
log_info "If needed, add user-level pip executables to PATH:
  export PATH=\"$USER_BIN:\$PATH\""

log_info "Python, pip, and uv setup complete."
