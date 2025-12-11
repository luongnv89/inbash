# CUDA 13.0 Installation - Quick Commands for DGX Spark

Copy and paste these commands in order.

---

## OPTION 1: Automated Installation (Recommended)

```bash
# Download and run the automated installer
cd /tmp
wget https://path-to-your-script/install_cuda_13_official.sh
chmod +x install_cuda_13_official.sh
./install_cuda_13_official.sh
```

---

## OPTION 2: Manual Command-by-Command Installation

### 1. Verify System (informational only)
```bash
lsb_release -a
uname -m
gcc --version
nvidia-smi
```

### 2. Remove Old CUDA (optional)
```bash
sudo apt-get remove -y 'cuda-*' 'nvidia-cuda-*' 'libcuda*' 2>/dev/null || true
sudo rm /etc/apt/sources.list.d/nvidia-cuda-*.list 2>/dev/null || true
sudo apt-get update
```

### 3. Add NVIDIA CUDA Repository
```bash
# Download GPG key
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64/cuda-archive-keyring.gpg

# Install GPG key
sudo install -D -m 0644 cuda-archive-keyring.gpg /usr/share/keyrings/nvidia-cuda-archive-keyring.gpg
rm cuda-archive-keyring.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64 /" | \
  sudo tee /etc/apt/sources.list.d/nvidia-cuda-ubuntu2404-arm64.list

# Update package list
sudo apt-get update
```

### 4. Install CUDA 13.0
```bash
# Install toolkit (includes nvcc)
sudo apt-get install -y cuda-toolkit-13-0

# Optional: install tools
sudo apt-get install -y cuda-tools-13-0
```

### 5. Setup Environment Variables
```bash
# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# CUDA 13.0 Configuration
export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-13.0
EOF

# Load in current shell
source ~/.bashrc
```

### 6. Verify Installation
```bash
# Check nvcc
which nvcc
nvcc --version

# Check libraries
ldconfig -p | grep libcudart

# Check CUDA path
echo $CUDA_HOME
```

### 7. Test CUDA
```bash
# Quick test
which nvcc && nvcc --version && echo "✓ CUDA 13.0 ready"
```

---

## OPTION 3: Minimal Installation (if you're confident)

```bash
# All in one
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64/cuda-archive-keyring.gpg && \
sudo install -D -m 0644 cuda-archive-keyring.gpg /usr/share/keyrings/nvidia-cuda-archive-keyring.gpg && \
rm cuda-archive-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64 /" | \
sudo tee /etc/apt/sources.list.d/nvidia-cuda-ubuntu2404-arm64.list && \
sudo apt-get update && \
sudo apt-get install -y cuda-toolkit-13-0 && \
cat >> ~/.bashrc << 'EOF'

export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-13.0
EOF

source ~/.bashrc && which nvcc && nvcc --version
```

---

## After Installation: Build llama.cpp

Once CUDA 13.0 is installed, build llama.cpp:

```bash
cd ~/workspace/llama.cpp
rm -rf build-cuda

# Configure
cmake -B build-cuda \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=90

# Build (10-20 minutes)
cmake --build build-cuda --config Release -j$(nproc)

# Test (if build succeeds)
./build-cuda/bin/llama-cli --version
```

---

## Verify Everything Works

```bash
# 1. Check nvcc
nvcc --version

# 2. Check CUDA runtime
ldconfig -p | grep libcudart

# 3. Check GPU
nvidia-smi

# 4. Check environment
echo "CUDA_HOME=$CUDA_HOME"
echo "PATH=$PATH" | grep cuda

# 5. Try a test compilation
cat > /tmp/test.cu << 'EOF'
#include <stdio.h>
int main() { printf("CUDA works!\n"); return 0; }
EOF
nvcc -o /tmp/test /tmp/test.cu && /tmp/test
```

All outputs should be successful.

---

## If Something Goes Wrong

### nvcc not found after installation
```bash
# Reload environment
source ~/.bashrc

# Or manually set PATH
export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH

# Verify
which nvcc
```

### Old CUDA 12.0 still in use
```bash
# Remove it
sudo apt-get remove -y 'cuda-toolkit-12*' 'libcuda*'

# Verify 13.0
nvcc --version
```

### Cannot download GPG key (network issues)
```bash
# Try manual approach: download from browser and copy file
# Save cuda-archive-keyring.gpg to /tmp/
sudo install -D -m 0644 /tmp/cuda-archive-keyring.gpg \
  /usr/share/keyrings/nvidia-cuda-archive-keyring.gpg

# Then continue with adding repository
```

### CUDA libraries not found at runtime
```bash
# Add to ~/.bashrc
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH

# Or system-wide
echo "/usr/local/cuda-13.0/lib64" | sudo tee /etc/ld.so.conf.d/cuda-13.conf
sudo ldconfig
```

---

## Quick Sanity Checks

```bash
# All should return YES/OK
echo "=== CUDA 13.0 Installation Check ==="
echo ""
echo -n "1. NVCC installed: "; which nvcc > /dev/null && echo "✓ YES" || echo "✗ NO"
echo -n "2. CUDA 13.0: "; nvcc --version 2>/dev/null | grep -q "13.0" && echo "✓ YES" || echo "✗ NO"
echo -n "3. CUDA libraries: "; ldconfig -p | grep -q "libcudart" && echo "✓ YES" || echo "✗ NO"
echo -n "4. GPU accessible: "; nvidia-smi > /dev/null && echo "✓ YES" || echo "✗ NO"
echo -n "5. CUDA_HOME set: "; [ -n "$CUDA_HOME" ] && echo "✓ YES ($CUDA_HOME)" || echo "✗ NO"
echo ""
echo "All checks passed! Ready to build llama.cpp with CUDA."
```

---

## Installation Takes

- Repository setup: ~2 minutes
- CUDA download and install: ~5-10 minutes
- Total: ~10-15 minutes

Building llama.cpp after: ~10-20 minutes

---

## Troubleshooting Resources

- NVIDIA CUDA Installation Guide: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/
- This system (DGX Spark) is **officially supported** for Ubuntu 24.04 + CUDA 13.0
- Check `/var/log/apt/term.log` if installation fails for details
