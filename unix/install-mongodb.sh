#!/usr/bin/env bash

###############################################################################
# inbash :: install-mongodb.sh
# ---------------------------------------------------------------------------
# Description : Installs MongoDB Community Edition from the official MongoDB
#               APT repository on Debian/Ubuntu systems.
# Usage       : ./install-mongodb.sh [-y|--yes] [--major-version <version>]
# Example     : ./install-mongodb.sh --yes --major-version 8.0
# Requirements: apt, curl, sudo/root privileges, network connectivity.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_MAJOR_VERSION="8.0"

AUTO_APPROVE=0
MAJOR_VERSION="$DEFAULT_MAJOR_VERSION"

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes                 Run without confirmation prompts.
      --major-version VER   MongoDB major version to install (default: $DEFAULT_MAJOR_VERSION).
  -h, --help                Show this help message.

Installs mongodb-org packages and enables the mongod service.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --major-version)
      MAJOR_VERSION="$2"
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

ensure_command curl
ensure_command tee
ensure_command apt-get

if [[ ${EUID:-0} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    log_error "Root privileges or sudo access are required."
    exit 1
  fi
else
  SUDO=""
fi

if [[ $AUTO_APPROVE -eq 0 ]]; then
  log_warn "MongoDB will be installed system-wide using version $MAJOR_VERSION."
  read -r -p "Proceed with the installation? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Preparing apt dependencies..."
$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl gnupg

UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
KEY_PATH="/usr/share/keyrings/mongodb-server-${MAJOR_VERSION}.gpg"
REPO_PATH="/etc/apt/sources.list.d/mongodb-org-${MAJOR_VERSION}.list"
GPG_URL="https://pgp.mongodb.com/server-${MAJOR_VERSION}.asc"

log_info "Importing MongoDB GPG key from $GPG_URL ..."
$SUDO install -m 0755 -d /usr/share/keyrings
curl -fsSL "$GPG_URL" | $SUDO gpg --dearmor -o "$KEY_PATH"
$SUDO chmod a+r "$KEY_PATH"

log_info "Configuring MongoDB apt repository for $UBUNTU_CODENAME..."
echo "deb [ arch=amd64,arm64 signed-by=$KEY_PATH ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/$MAJOR_VERSION multiverse" | \
  $SUDO tee "$REPO_PATH" >/dev/null

log_info "Refreshing apt package index..."
$SUDO apt-get update -y

log_info "Installing mongodb-org packages..."
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y mongodb-org

log_info "Enabling and starting mongod service..."
$SUDO systemctl enable mongod >/dev/null
$SUDO systemctl start mongod

if $SUDO systemctl is-active --quiet mongod; then
  log_info "MongoDB installation succeeded. Service status: active."
else
  log_warn "MongoDB service is not active. Check 'sudo systemctl status mongod'."
fi

log_info "Installation complete. Use 'mongosh' to connect to the server."