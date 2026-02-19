#!/usr/bin/env bash

###############################################################################
# inbash :: unix/setup-ssh.sh
# ---------------------------------------------------------------------------
# Description : Sets up a Debian/Ubuntu machine for remote SSH access.
#               Checks current SSH status, installs openssh-server, validates
#               the setup, and prints connection instructions.
# Usage       : ./setup-ssh.sh [-y|--yes]
# Example     : ./setup-ssh.sh --yes
# Requirements: apt, sudo/root privileges, Debian/Ubuntu Linux.
###############################################################################

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

AUTO_APPROVE=0

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  -y, --yes   Run without confirmation prompts.
  -h, --help  Show this help message.

Sets up SSH remote access on Debian/Ubuntu systems:
  1. Checks current SSH server status
  2. Installs openssh-server and openssh-client
  3. Enables and starts the sshd service
  4. Configures firewall (UFW) if active
  5. Validates the setup
  6. Prints connection instructions
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

# --- Linux-only guard ---
if [[ "$(uname -s)" != "Linux" ]]; then
  log_error "This script is intended for Linux (Debian/Ubuntu) systems only."
  log_error "Detected OS: $(uname -s)"
  exit 1
fi

# --- Privilege escalation ---
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

# ---------------------------------------------------------------------------
# 1. Check current SSH status
# ---------------------------------------------------------------------------
check_ssh_status() {
  log_info "--- Checking current SSH status ---"

  # openssh-server installed?
  if dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then
    log_info "openssh-server is installed."
  else
    log_warn "openssh-server is NOT installed."
  fi

  # sshd service active?
  if systemctl is-active --quiet ssh 2>/dev/null; then
    log_info "sshd service is active (running)."
  else
    log_warn "sshd service is NOT active."
  fi

  # sshd enabled on boot?
  if systemctl is-enabled --quiet ssh 2>/dev/null; then
    log_info "sshd service is enabled on boot."
  else
    log_warn "sshd service is NOT enabled on boot."
  fi

  # Port 22 listening?
  if ss -tlnp 2>/dev/null | grep -q ':22 '; then
    log_info "Port 22 is listening."
  else
    log_warn "Port 22 is NOT listening."
  fi
}

# ---------------------------------------------------------------------------
# 2. Install SSH
# ---------------------------------------------------------------------------
install_ssh() {
  log_info "--- Installing SSH server ---"

  log_info "Updating apt package index..."
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y

  log_info "Installing openssh-server openssh-client..."
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y openssh-server openssh-client

  log_info "Enabling sshd service on boot..."
  $SUDO systemctl enable ssh

  log_info "Starting sshd service..."
  $SUDO systemctl start ssh

  # If UFW is active, allow SSH traffic
  if command -v ufw >/dev/null 2>&1; then
    if $SUDO ufw status 2>/dev/null | grep -q 'Status: active'; then
      log_info "UFW is active — allowing port 22/tcp..."
      $SUDO ufw allow 22/tcp
    else
      log_info "UFW is installed but not active — skipping firewall rule."
    fi
  else
    log_info "UFW not found — skipping firewall configuration."
  fi
}

# ---------------------------------------------------------------------------
# 3. Validate SSH setup
# ---------------------------------------------------------------------------
validate_ssh() {
  log_info "--- Validating SSH setup ---"
  local checks_passed=0
  local checks_total=3

  # Check 1: sshd running
  if systemctl is-active --quiet ssh 2>/dev/null; then
    log_info "[PASS] sshd service is running."
    checks_passed=$((checks_passed + 1))
  else
    log_error "[FAIL] sshd service is NOT running."
  fi

  # Check 2: port 22 listening
  if ss -tlnp 2>/dev/null | grep -q ':22 '; then
    log_info "[PASS] Port 22 is listening."
    checks_passed=$((checks_passed + 1))
  else
    log_error "[FAIL] Port 22 is NOT listening."
  fi

  # Check 3: local SSH connectivity
  # Both success (exit 0) and "Permission denied" (exit 255) confirm sshd responds
  local ssh_exit=0
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no localhost exit 2>/dev/null || ssh_exit=$?
  if [[ $ssh_exit -eq 0 || $ssh_exit -eq 255 ]]; then
    log_info "[PASS] sshd is responding on localhost."
    checks_passed=$((checks_passed + 1))
  else
    log_error "[FAIL] sshd is NOT responding on localhost (exit code: $ssh_exit)."
  fi

  log_info "Validation: $checks_passed/$checks_total checks passed."
}

# ---------------------------------------------------------------------------
# 4. Print connection info
# ---------------------------------------------------------------------------
print_connection_info() {
  log_info "--- Connection Instructions ---"

  local current_user
  current_user="$(whoami)"
  local current_hostname
  current_hostname="$(hostname)"

  echo ""
  echo "=============================================="
  echo "  SSH Remote Access Setup Complete"
  echo "=============================================="
  echo ""
  echo "Hostname : $current_hostname"
  echo "User     : $current_user"
  echo ""

  # Gather IP addresses
  echo "IP Addresses:"
  if command -v ip >/dev/null 2>&1; then
    ip -o addr show 2>/dev/null | awk '
      $3 == "inet" && $4 !~ /^127\./ {
        split($4, a, "/"); printf "  %s: %s\n", $2, a[1]
      }
      $3 == "inet6" && $4 !~ /^fe80/ && $4 !~ /^::1/ {
        split($4, a, "/"); printf "  %s (v6): %s\n", $2, a[1]
      }'
  elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig 2>/dev/null | awk '
      /^[^ ]/ {iface=$1}
      /inet / && $2 !~ /^127\./ {print "  " iface " " $2}
      /inet6/ && $0 !~ /fe80/ && $0 !~ /::1/ {print "  " iface " (v6) " $2}'
  else
    echo "  (ip and ifconfig not available)"
  fi

  # Pick first non-loopback IPv4 for examples
  local first_ip=""
  if command -v ip >/dev/null 2>&1; then
    first_ip=$(ip -o -4 addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')
  elif command -v hostname >/dev/null 2>&1; then
    first_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi
  first_ip="${first_ip:-<IP_ADDRESS>}"

  echo ""
  echo "----------------------------------------------"
  echo "  1. Connect from another machine:"
  echo "----------------------------------------------"
  echo ""
  echo "    ssh ${current_user}@${first_ip}"
  echo ""
  echo "----------------------------------------------"
  echo "  2. Suggested ~/.ssh/config entry:"
  echo "----------------------------------------------"
  echo ""
  echo "    Host ${current_hostname}"
  echo "        HostName ${first_ip}"
  echo "        User ${current_user}"
  echo "        Port 22"
  echo ""
  echo "----------------------------------------------"
  echo "  3. Set up key-based authentication:"
  echo "----------------------------------------------"
  echo ""
  echo "    # On the CLIENT machine, generate a key (if you don't have one):"
  echo "    ssh-keygen -t ed25519"
  echo ""
  echo "    # Copy the public key to this server:"
  echo "    ssh-copy-id ${current_user}@${first_ip}"
  echo ""
  echo "----------------------------------------------"
  echo "  4. Verify connectivity:"
  echo "----------------------------------------------"
  echo ""
  echo "    ssh ${current_user}@${first_ip} \"hostname\""
  echo ""
  echo "=============================================="
}

# ---------------------------------------------------------------------------
# 5. Main
# ---------------------------------------------------------------------------
main() {
  if [[ $AUTO_APPROVE -eq 0 ]]; then
    log_warn "This script will install and configure SSH server for remote access."
    read -r -p "Proceed with SSH setup? [y/N] " response
    case "$response" in
      [yY][eE][sS]|[yY]) ;;
      *)
        log_warn "Setup cancelled by user."
        exit 0
        ;;
    esac
  fi

  check_ssh_status
  install_ssh
  validate_ssh
  print_connection_info

  log_info "SSH setup complete."
}

main "$@"
