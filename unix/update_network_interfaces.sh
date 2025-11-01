#!/usr/bin/env bash

###############################################################################
# inbash :: update_network_interfaces.sh
# ---------------------------------------------------------------------------
# Description : Deploys a prepared /etc/network/interfaces configuration file
#               and brings specified interfaces online on Debian/Ubuntu.
# Usage       : ./update_network_interfaces.sh [-y|--yes] [--source <path>] \
#                 [--interfaces "eth1 eth2"] [--dry-run]
# Example     : ./update_network_interfaces.sh --yes --interfaces "eth1"
# Requirements: sudo/root privileges, ifupdown utilities, prepared config file.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_SOURCE="$(dirname "$0")/interfaces"
readonly TARGET_FILE="/etc/network/interfaces"

AUTO_APPROVE=0
DRY_RUN=0
SOURCE_FILE="$DEFAULT_SOURCE"
INTERFACES_TO_BRING_UP=(eth1)

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes            Apply changes without confirmation.
      --source PATH    Path to interfaces template (default: $DEFAULT_SOURCE).
      --interfaces STR Space-separated interface names to bring up (default: eth1).
      --dry-run        Show actions without modifying system files.
  -h, --help           Show this help message.

The script will back up the existing interfaces file and copy the new
configuration into place before running ifup on selected interfaces.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=1
      shift
      ;;
    --source)
      SOURCE_FILE="$2"
      shift 2
      ;;
    --interfaces)
      read -r -a INTERFACES_TO_BRING_UP <<<"$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
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

if [[ ! -f "$SOURCE_FILE" ]]; then
  log_error "Source file '$SOURCE_FILE' does not exist."
  exit 1
fi

if [[ ${#INTERFACES_TO_BRING_UP[@]} -eq 0 ]]; then
  log_error "No interfaces specified."
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

log_info "Planned interfaces: ${INTERFACES_TO_BRING_UP[*]}"
log_info "Source file: $SOURCE_FILE"
log_info "Target file: $TARGET_FILE"

if [[ $AUTO_APPROVE -eq 0 ]]; then
  read -r -p "Proceed with updating $TARGET_FILE? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *)
      log_warn "Operation cancelled by user."
      exit 0
      ;;
  esac
fi

if [[ $DRY_RUN -eq 1 ]]; then
  log_info "Dry-run mode: skipping file copy and interface activation."
  exit 0
fi

if [[ -f "$TARGET_FILE" ]]; then
  backup_path="$TARGET_FILE.$(date +%Y%m%d%H%M%S).bak"
  log_info "Backing up existing interfaces file to $backup_path"
  $SUDO cp "$TARGET_FILE" "$backup_path"
fi

log_info "Copying new interfaces configuration into place..."
$SUDO install -m 0644 "$SOURCE_FILE" "$TARGET_FILE"

for iface in "${INTERFACES_TO_BRING_UP[@]}"; do
  log_info "Bringing up interface $iface"
  if $SUDO ifup "$iface"; then
    log_info "$iface is up"
  else
    log_warn "Failed to bring up $iface. Check logs with 'journalctl -xe' or 'dmesg'."
  fi
done

log_info "Current interface status:"
$SUDO ip addr show

log_info "Network interfaces update complete."