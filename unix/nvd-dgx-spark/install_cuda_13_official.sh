#!/bin/bash
# CUDA 13.0 Installation for NVIDIA DGX Spark (ARM64 SBSA)
# Based on official NVIDIA CUDA Installation Guide for Linux 13.0
# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ CUDA 13.0 Installation for DGX Spark (ARM64 SBSA)         ║"
echo "║ Based on NVIDIA Official Documentation                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Verify prerequisites
echo "[1/7] Verifying prerequisites..."
echo ""

# Check if running on Ubuntu 24.04
OS_VERSION=$(lsb_release -sr)
if [[ "$OS_VERSION" != "24.04" ]]; then
    echo "⚠️  Warning: Ubuntu $OS_VERSION detected. CUDA 13.0 is officially supported on Ubuntu 24.04"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
    echo "❌ Error: This script is for ARM64 (aarch64). Your architecture is: $ARCH"
    exit 1
fi

echo "✓ Ubuntu $OS_VERSION (arm64) detected"
echo "✓ GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
echo "✓ Driver Version: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
echo ""

# Step 2: Remove any existing CUDA packages
echo "[2/7] Removing any existing CUDA 12.x installations..."
sudo apt-get remove -y cuda-* nvidia-cuda-* 2>/dev/null || true
echo "✓ Cleaned up old CUDA packages"
echo ""

# Step 3: Add NVIDIA CUDA repository for ARM64 SBSA
echo "[3/7] Adding NVIDIA CUDA repository for ARM64 SBSA..."

# Set up repository variables for Ubuntu 24.04
REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64"
KEYRING="/usr/share/keyrings/nvidia-cuda-archive-keyring.gpg"

# Download and install NVIDIA GPG key
echo "  → Installing NVIDIA GPG key..."
wget -qO /tmp/cuda-archive-keyring.gpg ${REPO_URL}/cuda-archive-keyring.gpg
sudo install -D -m 0644 /tmp/cuda-archive-keyring.gpg $KEYRING
rm /tmp/cuda-archive-keyring.gpg

# Add CUDA repository
echo "  → Adding CUDA repository..."
echo "deb [signed-by=$KEYRING] $REPO_URL /" | sudo tee /etc/apt/sources.list.d/nvidia-cuda-ubuntu2404-arm64.list

echo "✓ CUDA repository added"
echo ""

# Step 4: Update package list
echo "[4/7] Updating package manager..."
sudo apt-get update
echo "✓ Package list updated"
echo ""

# Step 5: Install CUDA Toolkit 13.0
echo "[5/7] Installing CUDA Toolkit 13.0..."
echo "  This may take several minutes..."
echo ""

# Install CUDA 13.0 toolkit
sudo apt-get install -y cuda-toolkit-13-0

# Install development tools (optional but recommended for compiling)
sudo apt-get install -y cuda-tools-13-0

echo ""
echo "✓ CUDA 13.0 Toolkit installed"
echo ""

# Step 6: Setup environment variables
echo "[6/7] Setting up environment variables..."

# Create/append to bashrc
CUDA_ENV='
# CUDA 13.0 Environment Variables
export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-13.0
'

# Add to current shell
eval "$(echo "$CUDA_ENV")"

# Add to ~/.bashrc for persistence
if ! grep -q "CUDA_HOME=/usr/local/cuda-13.0" ~/.bashrc; then
    echo "$CUDA_ENV" >> ~/.bashrc
    echo "✓ Added CUDA environment variables to ~/.bashrc"
else
    echo "✓ CUDA environment variables already in ~/.bashrc"
fi

echo ""

# Step 7: Verify installation
echo "[7/7] Verifying CUDA installation..."
echo ""

if command -v nvcc &> /dev/null; then
    NVCC_VERSION=$(nvcc --version | grep release)
    echo "✓ NVCC found:"
    echo "  $NVCC_VERSION"
else
    echo "❌ NVCC not found in PATH"
    echo "   Try: source ~/.bashrc"
    echo "   Or restart your terminal"
fi

echo ""
echo "✓ CUDA runtime found:"
ldconfig -p | grep libcudart | head -1 | awk '{print "  " $0}'

echo ""
echo "✓ CUDA path:"
echo "  $(which nvcc)"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             CUDA 13.0 Installation Complete              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo "Next steps:"
echo "  1. Source your bashrc to load CUDA environment:"
echo "     source ~/.bashrc"
echo ""
echo "  2. Build llama.cpp with CUDA support:"
echo "     cd ~/workspace/llama.cpp"
echo "     rm -rf build-cuda"
echo "     cmake -B build-cuda -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=90"
echo "     cmake --build build-cuda -j\$(nproc)"
echo ""
echo "  3. Verify nvcc works:"
echo "     nvcc --version"
echo ""
echo "  4. Verify GPU access:"
echo "     nvidia-smi"
echo ""
echo "For more information:"
echo "  - CUDA Toolkit Documentation: https://docs.nvidia.com/cuda/cuda-toolkit-archive/"
echo "  - CUDA Installation Guide: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/"
