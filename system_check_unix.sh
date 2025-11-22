#!/usr/bin/env bash

###############################################################################
# inbash :: system_check_unix.sh
# ---------------------------------------------------------------------------
# Description : Quick system spec + status report for macOS & Linux (OS, CPU,
#               GPU, memory, disks).
# Usage       : ./system_check_unix.sh
# Example     : ./system_check_unix.sh
# Requirements: macOS or Linux with common system utilities (uname, awk, df).
###############################################################################

set -euo pipefail

print_header() {
  echo
  echo "===== $1 ====="
}

get_os_info() {
  print_header "OS INFO"
  local os_type
  os_type=$(uname -s)

  echo "Kernel: $(uname -sr)"

  if [[ "$os_type" == "Darwin" ]]; then
    # macOS
    if command -v sw_vers >/dev/null 2>&1; then
      echo "OS: macOS $(sw_vers -productName) $(sw_vers -productVersion) (Build $(sw_vers -buildVersion))"
    else
      echo "OS: macOS (sw_vers not available)"
    fi
  elif [[ "$os_type" == "Linux" ]]; then
    if [[ -f /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      echo "OS: ${NAME} ${VERSION}"
    else
      echo "OS: Linux (no /etc/os-release)"
    fi
  else
    echo "OS: Unknown ($os_type)"
  fi

  echo "Hostname: $(hostname)"
  echo "Uptime: $(uptime | sed 's/^[^,]*up *//; s/, *[0-9]* user.*//')"
}

get_cpu_info() {
  print_header "CPU INFO"
  local os_type
  os_type=$(uname -s)

  if [[ "$os_type" == "Darwin" ]]; then
    # macOS
    local brand phys logical
    brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    phys=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "Unknown")
    logical=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "Unknown")

    echo "Model: $brand"
    echo "Physical cores: $phys"
    echo "Logical cores:  $logical"
  elif [[ "$os_type" == "Linux" ]]; then
    # Linux
    local model phys logical
    if command -v lscpu >/dev/null 2>&1; then
      model=$(lscpu | awk -F: '/Model name/ {gsub(/^ +/,"",$2); print $2; exit}')
      phys=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^ +/,"",$2); cores=$2} /^Socket\(s\)/ {gsub(/^ +/,"",$2); sockets=$2} END {if (cores && sockets) print cores*sockets}')
      logical=$(lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^ +/,"",$2); print $2; exit}')
    else
      model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ *//')
      logical=$(nproc --all 2>/dev/null || echo "Unknown")
      phys="Unknown"
    fi

    echo "Model: ${model:-Unknown}"
    echo "Physical cores: ${phys:-Unknown}"
    echo "Logical cores:  ${logical:-Unknown}"
  else
    echo "Unknown OS type for CPU info"
  fi
}

get_gpu_info() {
  print_header "GPU INFO"
  local os_type
  os_type=$(uname -s)

  if [[ "$os_type" == "Darwin" ]]; then
    if command -v system_profiler >/dev/null 2>&1; then
      system_profiler SPDisplaysDataType 2>/dev/null | \
        awk -F: '
          /Chipset Model/ {
            gsub(/^ +/,"",$2);
            print "GPU: " $2
          }
          /VRAM/ {
            gsub(/^ +/,"",$2);
            print "  VRAM: " $2
          }'
    else
      echo "system_profiler not available."
    fi
  elif [[ "$os_type" == "Linux" ]]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
      echo "NVIDIA GPU(s):"
      nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | \
        awk -F, '{printf "  GPU: %s | VRAM: %s | Driver: %s\n", $1, $2, $3}'
    fi

    if command -v lspci >/dev/null 2>&1; then
      echo "PCI GPU / Display controllers:"
      lspci | grep -Ei 'vga|3d|display' || echo "  (none detected by lspci)"
    else
      echo "lspci not available."
    fi
  else
    echo "Unknown OS type for GPU info"
  fi
}

get_mem_info() {
  print_header "MEMORY INFO"
  local os_type
  os_type=$(uname -s)

  if [[ "$os_type" == "Darwin" ]]; then
    # Total RAM
    local total_bytes
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    if [[ "$total_bytes" -gt 0 ]]; then
      awk -v b="$total_bytes" 'BEGIN {printf "Total: %.1f GB\n", b/1024/1024/1024}'
    else
      echo "Total: Unknown"
    fi

    # Use top for quick overview
    if command -v top >/dev/null 2>&1; then
      top -l 1 -s 0 | awk '/PhysMem/ {print "Usage: "$0}'
    else
      echo "top not available for detailed usage."
    fi

  elif [[ "$os_type" == "Linux" ]]; then
    if command -v free >/dev/null 2>&1; then
      free -h | awk '
        NR==1 {print $0}
        NR==2 {printf "Total: %s | Used: %s | Free: %s | Shared: %s | Buff/Cache: %s | Available: %s\n",$2,$3,$4,$5,$6,$7}'
    else
      echo "free command not available."
    fi
  else
    echo "Unknown OS type for memory info"
  fi
}

get_disk_info() {
  print_header "DISK INFO"
  local os_type
  os_type=$(uname -s)

  if [[ "$os_type" == "Darwin" ]]; then
    # Show main device-backed filesystems
    df -h | awk 'NR==1 || /^\/dev\//'
  elif [[ "$os_type" == "Linux" ]]; then
    # Exclude tmpfs, devtmpfs
    if df -h -x tmpfs -x devtmpfs >/dev/null 2>&1; then
      df -h -x tmpfs -x devtmpfs
    else
      # Fallback if -x unsupported
      df -h
    fi
  else
    df -h
  fi
}

main() {
  echo "System Check (Unix) - $(date)"
  echo "================================"

  get_os_info
  get_cpu_info
  get_gpu_info
  get_mem_info
  get_disk_info

  echo
  echo "Done."
}

main "$@"
