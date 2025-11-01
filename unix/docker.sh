#!/usr/bin/env bash

###############################################################################
# inbash :: docker.sh
# ---------------------------------------------------------------------------
# Description : Installs Docker Engine, CLI, containerd and Compose plugin on
#               Debian/Ubuntu systems using the official Docker repository.
# Usage       : ./docker.sh [-y|--yes] [--remove-repo]
# Example     : ./docker.sh --yes
# Requirements: apt, curl, sudo/root privileges, network connectivity.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DOCKER_GPG_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
readonly DOCKER_APT_SOURCE="/etc/apt/sources.list.d/docker.list"
readonly DOCKER_KEYRING="/etc/apt/keyrings/docker.asc"
readonly PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)

AUTO_APPROVE=0
REMOVE_REPO=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes        Run without confirmation prompts.
      --remove-repo Remove Docker apt repository after installation.
  -h, --help       Show this help message.

Installs Docker Engine components: ${PACKAGES[*]}.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --remove-repo)
      REMOVE_REPO=1
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

ensure_command curl
ensure_command lsb_release
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
  log_warn "This script will modify apt repositories and install Docker packages."
  read -r -p "Proceed with Docker installation? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Installation cancelled by user."
      exit 0
      ;;
  esac
fi

log_info "Ensuring prerequisites are installed..."
$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl gnupg

log_info "Setting up Docker GPG key..."
$SUDO install -m 0755 -d /etc/apt/keyrings
curl -fsSL "$DOCKER_GPG_KEY_URL" | $SUDO gpg --dearmor -o "$DOCKER_KEYRING"
$SUDO chmod a+r "$DOCKER_KEYRING"

log_info "Configuring Docker apt repository..."
UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
echo "deb [arch=$(dpkg --print-architecture) signed-by=$DOCKER_KEYRING] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | \
  $SUDO tee "$DOCKER_APT_SOURCE" >/dev/null

log_info "Updating apt package index..."
$SUDO apt-get update -y

log_info "Installing Docker packages: ${PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "${PACKAGES[@]}"

log_info "Verifying Docker installation..."
if $SUDO systemctl is-active --quiet docker; then
  log_info "Docker service is running."
else
  log_warn "Docker service is not running. You can start it with: sudo systemctl start docker"
fi

if docker --version >/dev/null 2>&1; then
  log_info "Docker CLI version: $(docker --version)"
fi

if [[ $REMOVE_REPO -eq 1 ]]; then
  log_info "Removing Docker apt repository configuration..."
  $SUDO rm -f "$DOCKER_APT_SOURCE"
  log_info "Repository removed. Run 'sudo apt-get update' if you no longer need Docker updates."
fi

log_info "Docker installation complete. Run 'sudo docker run hello-world' to verify."