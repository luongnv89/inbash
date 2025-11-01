#!/usr/bin/env bash

###############################################################################
# inbash :: mount-share.sh
# ---------------------------------------------------------------------------
# Description : Mounts a VirtualBox shared folder inside a guest system with
#               helpful diagnostics for missing kernel modules.
# Usage       : ./mount-share.sh --share <name> --target <path> [-y|--yes]
# Example     : ./mount-share.sh --share workspace --target ~/workspace --yes
# Requirements: VirtualBox guest additions, sudo/root privileges.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

SHARE_NAME=""
TARGET_PATH=""
AUTO_APPROVE=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME --share NAME --target PATH [options]

Options:
      --share NAME   Name of the VirtualBox shared folder (required).
      --target PATH  Mount point inside the guest (required).
  -y, --yes          Run without confirmation prompts.
  -h, --help         Show this help message.

Troubleshooting:
  1) If you see "No such device":
     sudo modprobe -a vboxguest vboxsf vboxvideo
  2) If filesystem type 'vboxsf' is unknown:
     sudo apt-get install -y virtualbox-guest-utils virtualbox-guest-dkms
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --share)
      SHARE_NAME="$2"
      shift 2
      ;;
    --target)
      TARGET_PATH="$2"
      shift 2
      ;;
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

if [[ -z "$SHARE_NAME" || -z "$TARGET_PATH" ]]; then
  log_error "Both --share and --target arguments are required."
  usage
  exit 1
fi

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

if ! lsmod | grep -q vboxsf; then
  log_warn "vboxsf kernel module not detected. Running 'modprobe vboxsf'..."
  if ! $SUDO modprobe vboxsf 2>/dev/null; then
    log_warn "Could not load vboxsf. Verify VirtualBox guest additions are installed."
  fi
fi

log_info "Mounting shared folder '$SHARE_NAME' to '$TARGET_PATH'"

if [[ $AUTO_APPROVE -eq 0 ]]; then
  read -r -p "Proceed with mounting? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Mount cancelled by user."
      exit 0
      ;;
  esac
fi

if [[ ! -d "$TARGET_PATH" ]]; then
  log_info "Creating target directory $TARGET_PATH"
  $SUDO mkdir -p "$TARGET_PATH"
fi

uid=$(id -u)
gid=$(id -g)

if $SUDO mount -t vboxsf -o uid="$uid",gid="$gid" "$SHARE_NAME" "$TARGET_PATH"; then
  log_info "Mount successful."
  log_info "Verify with: mount | grep vboxsf"
else
  log_error "Mount failed. See troubleshooting steps in --help output."
  exit 1
fi
