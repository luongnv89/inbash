# Manual CUDA 13.0 Installation for DGX Spark (ARM64 SBSA)
## Based on NVIDIA CUDA Installation Guide for Linux 13.0

---

## Overview

You're installing CUDA 13.0 on **Ubuntu 24.04** with **ARM64 SBSA** architecture (NVIDIA Grace Hopper).
This is the officially supported configuration.

---

## Prerequisites

Verify you have:
- NVIDIA Grace Hopper GPU (DGX Spark) ✓
- Ubuntu 24.04 LTS
- GCC compiler (required for host code compilation)
- Internet connection to NVIDIA repositories

Check your system:
```bash
lsb_release -a                 # Should show: Release: 24.04
uname -m                       # Should show: aarch64
gcc --version                  # Should be installed
nvidia-smi                     # Should show Grace Hopper GPU
```

---

## Step 1: Verify GPU and Current CUDA Status

```bash
# Check GPU
nvidia-smi
# Output should show:
#   NVIDIA GB10 (Grace Hopper)
#   CUDA Version: 13.0 (shown in driver output)

# Check what's currently installed
apt list --installed | grep cuda

# You may have CUDA 12.0 installed, which we'll replace
```

---

## Step 2: Remove Old CUDA Installation (Optional but Recommended)

If you have CUDA 12.0 installed and want a clean install:

```bash
# Remove old CUDA packages
sudo apt-get remove -y 'cuda-*' 'nvidia-cuda-*' 'libcuda*'

# Optional: Remove the old repository
sudo rm /etc/apt/sources.list.d/nvidia-cuda-*.list

# Update package lists
sudo apt-get update
```

**Note**: Ollama will continue working during this process - it doesn't depend on system CUDA packages.

---

## Step 3: Add NVIDIA CUDA Repository (Package Manager Installation)

NVIDIA provides official DEB repositories for Ubuntu. We'll use the network repository (auto-updates supported).

### 3.1 Download and Install NVIDIA GPG Key

```bash
# Download NVIDIA's GPG key for repository authentication
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64/cuda-archive-keyring.gpg

# Install the key
sudo install -D -m 0644 cuda-archive-keyring.gpg /usr/share/keyrings/nvidia-cuda-archive-keyring.gpg

# Clean up
rm cuda-archive-keyring.gpg
```

### 3.2 Add CUDA Repository Source

```bash
# Add the NVIDIA CUDA repository for Ubuntu 24.04 ARM64
echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64 /" | \
  sudo tee /etc/apt/sources.list.d/nvidia-cuda-ubuntu2404-arm64.list

# Update package list
sudo apt-get update
```

**Verify repository was added:**
```bash
cat /etc/apt/sources.list.d/nvidia-cuda-ubuntu2404-arm64.list
# Should show the CUDA repository URL
```

---

## Step 4: View Available CUDA 13.0 Packages

Before installing, see what's available:

```bash
# List all CUDA-related packages
apt-cache search cuda | head -30

# Check specific CUDA 13.0 toolkit package
apt-cache policy cuda-toolkit-13-0

# Expected output should show version 13.0.x available
```

---

## Step 5: Install CUDA Toolkit 13.0

### 5.1 Install Base Toolkit

```bash
# Install CUDA 13.0 Toolkit (includes nvcc compiler and libraries)
sudo apt-get install -y cuda-toolkit-13-0
```

This installs:
- `nvcc` compiler
- CUDA runtime libraries
- CUDA development headers
- Other CUDA development tools

**Installation time**: 5-10 minutes depending on internet speed

### 5.2 (Optional) Install Additional Tools

```bash
# Development tools (gdb debugger, profilers, etc.)
sudo apt-get install -y cuda-tools-13-0

# If you want future CUDA updates to go to 13.0 series
sudo apt-get install -y cuda-13-0
```

---

## Step 6: Configure Environment Variables

CUDA binaries and libraries need to be in your PATH and library path.

### 6.1 Permanent Configuration (Recommended)

Add CUDA environment variables to your shell profile:

```bash
# Edit your bashrc
nano ~/.bashrc

# Add these lines at the end (after any existing CUDA entries):
export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-13.0

# Save: Ctrl+O, Enter, Ctrl+X
```

Or use this one-liner:
```bash
cat >> ~/.bashrc << 'EOF'

# CUDA 13.0 Configuration
export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-13.0
EOF
```

### 6.2 Load Variables in Current Shell

```bash
# Apply environment variables to current terminal session
source ~/.bashrc
```

---

## Step 7: Verify Installation

### 7.1 Check NVCC Compiler

```bash
# Find nvcc
which nvcc
# Expected: /usr/local/cuda-13.0/bin/nvcc

# Check version
nvcc --version
# Expected: CUDA release 13.0
```

### 7.2 Check CUDA Libraries

```bash
# Find CUDA libraries
ldconfig -p | grep libcudart
# Should show: libcudart.so.12 -> /usr/local/cuda-13.0/lib64/libcudart.so.12

# Or check directly
ls -lh /usr/local/cuda-13.0/lib64/libcudart.so*
```

### 7.3 Check CUDA Samples (Optional)

```bash
# CUDA samples are available on GitHub
git clone https://github.com/nvidia/cuda-samples.git
cd cuda-samples
ls Samples/
```

---

## Step 8: Test CUDA Compilation

Create a simple test program:

```bash
# Create test file
cat > /tmp/test_cuda.cu << 'EOF'
#include <stdio.h>

__global__ void hello() {
    printf("Hello from GPU!\n");
}

int main() {
    hello<<<1,1>>>();
    cudaDeviceSynchronize();
    return 0;
}
EOF

# Compile with nvcc
nvcc -o /tmp/test_cuda /tmp/test_cuda.cu

# Run the test
/tmp/test_cuda
# Should output: Hello from GPU!
```

---

## Step 9: Fix llama.cpp Build

Now that CUDA 13.0 is installed, build llama.cpp:

```bash
cd ~/workspace/llama.cpp
rm -rf build-cuda

# Configure with CUDA support for Grace Hopper (sm_90)
cmake -B build-cuda \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=90 \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.0/bin/nvcc

# Build (this will take 10-20 minutes)
cmake --build build-cuda --config Release -j$(nproc)
```

**If the build completes successfully**, you'll have:
- `./build-cuda/bin/llama-cli` - command-line interface
- Other llama.cpp binaries with full CUDA support

---

## Troubleshooting

### Problem: "nvcc: command not found"

**Solution 1**: Reload environment variables
```bash
source ~/.bashrc
nvcc --version
```

**Solution 2**: Check PATH
```bash
echo $PATH
# Should include /usr/local/cuda-13.0/bin

# If not, add it manually
export PATH=/usr/local/cuda-13.0/bin:$PATH
```

### Problem: "error while loading shared libraries: libcudart.so.12"

**Solution**: Update library path
```bash
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
ldconfig -p | grep libcudart
```

### Problem: CMake still can't find CUDA

**Solution**: Explicitly set CMAKE variables
```bash
cmake -B build-cuda \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.0/bin/nvcc \
  -DCUDAToolkit_ROOT=/usr/local/cuda-13.0 \
  -DCMAKE_CUDA_ARCHITECTURES=90
```

### Problem: CUDA 12.0 still showing up

**Solution**: Remove CUDA 12.0 completely
```bash
# Check what's installed
dpkg -l | grep cuda

# Remove old packages
sudo apt-get remove -y 'cuda-toolkit-12*' 'nvidia-cuda-12*'

# Update
sudo apt-get update

# Check again
which nvcc  # Should show 13.0
```

---

## Verification Checklist

After installation, verify:

- [ ] `nvcc --version` shows CUDA 13.0
- [ ] `which nvcc` shows `/usr/local/cuda-13.0/bin/nvcc`
- [ ] `nvidia-smi` shows GPU with CUDA 13.0
- [ ] `ls /usr/local/cuda-13.0/lib64/libcudart*` shows CUDA libraries
- [ ] Environment variables are set: `echo $CUDA_HOME`
- [ ] llama.cpp builds successfully with `-DGGML_CUDA=ON`

---

## Uninstallation (if needed)

If you need to remove CUDA 13.0:

```bash
# Remove CUDA packages
sudo apt-get remove -y 'cuda-*' 'nvidia-cuda-*'

# Remove repository
sudo rm /etc/apt/sources.list.d/nvidia-cuda-ubuntu2404-arm64.list

# Remove GPG key
sudo rm /usr/share/keyrings/nvidia-cuda-archive-keyring.gpg

# Update
sudo apt-get update

# Remove environment variables from ~/.bashrc
nano ~/.bashrc  # Remove CUDA_HOME, PATH, and LD_LIBRARY_PATH lines
```

---

## Official References

- NVIDIA CUDA Installation Guide: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/
- CUDA Toolkit Archive: https://developer.nvidia.com/cuda-toolkit-archive
- CUDA Downloads: https://developer.nvidia.com/cuda-downloads
- CUDA Samples: https://github.com/nvidia/cuda-samples

---

## Notes

- **Ollama**: Your Ollama installation is independent and will not be affected by CUDA toolkit installation
- **CUDA Runtime**: The CUDA runtime libraries in Ollama's Docker containers are separate from system CUDA
- **Multiple Versions**: You can have both CUDA 12.0 and 13.0 installed simultaneously if needed (use `update-alternatives`)
- **PATH Order**: Environment variables should be set so CUDA 13.0 comes first in PATH

---

## Support

If you encounter issues:

1. Check the official NVIDIA documentation
2. Consult NVIDIA Developer Forums
3. Review build logs: `cmake --build build-cuda 2>&1 | tee build.log`
4. Verify GPU with: `nvidia-smi --query-gpu=compute_cap --format=csv,noheader`
