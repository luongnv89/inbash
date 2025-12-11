# Complete Guide: Running LLMs Locally on NVIDIA DGX Spark

A comprehensive guide combining official ggml setup instructions and community benchmarks for optimal local AI deployment.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Prerequisites & Initial Setup](#prerequisites--initial-setup)
3. [Quick Setup (Recommended)](#quick-setup-recommended)
4. [Manual Installation](#manual-installation)
5. [Recommended Models](#recommended-models)
6. [Benchmarking Your System](#benchmarking-your-system)
7. [Use Cases & Configuration](#use-cases--configuration)
8. [Performance Optimization](#performance-optimization)
9. [Troubleshooting](#troubleshooting)
10. [Advanced: Using Ollama](#advanced-using-ollama)

---

## System Overview

The NVIDIA DGX Spark features:
- **128GB unified memory** - Run large models that won't fit on typical GPUs
- **Blackwell architecture (sm_121)** - Optimized for MXFP4 quantization
- **Grace CPU** - ARM-based, unified with CUDA 13.0

### What You Can Run Simultaneously

| Service | Port | Model | Purpose |
|---------|------|-------|---------|
| Embeddings | 8021 | Nomic Embed v1.5 | Text embeddings for RAG |
| Code Completion | 8022 | Qwen2.5 Coder 7B | Fill-in-the-middle (FIM) |
| Chat/Tools | 8023 | GPT-OSS 120B | General LLM, chat, agents |
| Vision | 8024 | Qwen2-VL 7B | Image analysis |
| Speech-to-Text | 8025 | Whisper | Audio transcription |

**Note:** All models above are PUBLIC on HuggingFace. If you get "model is private" errors, run:
```bash
export HF_TOKEN=your_huggingface_token
```

---

## Prerequisites & Initial Setup

### 1. Verify Your CUDA Environment

```bash
# Check CUDA version (should be 13.0+)
nvcc --version

# Check GPU status
nvidia-smi
```

**Expected output:**
```
Cuda compilation tools, release 13.0, V13.0.88
```

### 2. Fix Common CUDA Issues

If you have CUDA 12 from Ubuntu repos conflicting with CUDA 13:

```bash
# Remove conflicting Ubuntu CUDA toolkit
sudo apt purge nvidia-cuda-toolkit

# Ensure CUDA 13 is in your PATH
echo 'export PATH="/usr/local/cuda-13/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify correct nvcc is used
which nvcc  # Should show /usr/local/cuda-13/bin/nvcc
```

### 3. Install Required Dependencies

```bash
sudo apt update
sudo apt install -y libcurl4-openssl-dev build-essential cmake git
```

---

## Quick Setup (Recommended)

The official ggml setup script handles everything automatically:

```bash
bash <(curl -s https://ggml.ai/dgx-spark.sh)
```

This script will:
- Clone and build llama.cpp and whisper.cpp with CUDA support
- Download optimized models for DGX Spark
- Start all AI services on ports 8021-8025

**First run takes several minutes** to download model weights (~60GB total).

### Verify Services Are Running

```bash
# Check all services
netstat -ntpl | grep "802"

# Or check nvidia-smi for GPU memory usage
nvidia-smi
```

### Starting Services After Installation (Without Reinstalling)

If you've already run the setup script once and just want to manage services, use the interactive service manager:

**Option A: Interactive Service Manager (Recommended)**

Download and run the interactive manager:
```bash
# Download the script
curl -o ~/ggml-services.sh https://your-server/ggml-services.sh
# Or copy from this guide's attachments

chmod +x ~/ggml-services.sh
~/ggml-services.sh
```

Features:
- Interactive menu to select which services to start/stop
- Checks if services are already running (won't duplicate)
- Color-coded status display
- Logs stored in `~/ggml-logs/`

Command line options:
```bash
~/ggml-services.sh              # Interactive mode
~/ggml-services.sh --start-all  # Start all services
~/ggml-services.sh --stop-all   # Stop all services  
~/ggml-services.sh --status     # Show status only
```

**Option B: Simple Startup Script**

For a basic script that starts all services:

```bash
#!/bin/bash
# Save as ~/start-ggml-services.sh

LLAMA_SERVER=~/ggml-org/llama.cpp/build-cuda/bin/llama-server
WHISPER_SERVER=~/ggml-org/whisper.cpp/build-cuda/bin/whisper-server
WHISPER_MODEL="$HOME/ggml-org/whisper.cpp/models/ggml-base.en.bin"

# Kill any existing services
pkill -f "llama-server" 2>/dev/null
pkill -f "whisper-server" 2>/dev/null
sleep 2

echo "Starting ggml AI services..."

# Port 8021: Embeddings (Nomic - PUBLIC)
$LLAMA_SERVER \
  -hf nomic-ai/nomic-embed-text-v1.5-GGUF \
  --port 8021 --host 0.0.0.0 \
  --embedding -ngl 99 --no-mmap &

# Port 8022: Code Completion / FIM (Qwen2.5 Coder - PUBLIC)
$LLAMA_SERVER \
  -hf Qwen/Qwen2.5-Coder-7B-Instruct-GGUF \
  --port 8022 --host 0.0.0.0 \
  --ctx-size 32768 -ngl 99 --no-mmap &

# Port 8023: Chat / Tools (GPT-OSS 120B - PUBLIC)
$LLAMA_SERVER \
  -hf ggml-org/gpt-oss-120b-GGUF \
  --port 8023 --host 0.0.0.0 \
  --ctx-size 131072 -np 8 --jinja \
  -ub 2048 -b 2048 -ngl 99 --no-mmap &

# Port 8024: Vision (Qwen2-VL - PUBLIC)
$LLAMA_SERVER \
  -hf Qwen/Qwen2-VL-7B-Instruct-GGUF \
  --port 8024 --host 0.0.0.0 \
  --ctx-size 8192 -ngl 99 --no-mmap &

# Port 8025: Speech-to-Text (Whisper)
$WHISPER_SERVER -m $WHISPER_MODEL \
  --port 8025 --host 0.0.0.0 &

echo "All services starting... Check with: netstat -ntpl | grep 802"
```

Make it executable and run:
```bash
chmod +x ~/start-ggml-services.sh
~/start-ggml-services.sh
```

### Stop All Services

```bash
pkill -f "llama-server"
pkill -f "whisper-server"
```

### Create a Systemd Service (Auto-Start on Boot)

```bash
# Create service file
sudo tee /etc/systemd/system/ggml-services.service << 'EOF'
[Unit]
Description=GGML AI Services
After=network.target

[Service]
Type=forking
User=YOUR_USERNAME
ExecStart=/home/YOUR_USERNAME/start-ggml-services.sh
ExecStop=/usr/bin/pkill -f llama-server ; /usr/bin/pkill -f whisper-server
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Replace YOUR_USERNAME and enable
sudo sed -i "s/YOUR_USERNAME/$USER/g" /etc/systemd/system/ggml-services.service
sudo systemctl daemon-reload
sudo systemctl enable ggml-services
sudo systemctl start ggml-services
```

---

## Manual Installation

For more control, build llama.cpp manually:

### Build llama.cpp

```bash
# Clone repository
git clone https://github.com/ggml-org/llama.cpp ~/llama.cpp
cd ~/llama.cpp

# Build with CUDA support
cmake -B build-cuda -DGGML_CUDA=ON
cmake --build build-cuda -j

# Verify build
./build-cuda/bin/llama-cli --version
```

### If You Encounter GCC/NVCC Conflicts

Some systems have GCC 13 issues with CUDA 13. Use GCC 12:

```bash
# Install GCC 12 if needed
sudo apt install g++-12

# Build with explicit compiler paths
cmake -B build-cuda \
  -DCMAKE_C_COMPILER=/usr/bin/gcc-12 \
  -DCMAKE_CXX_COMPILER=/usr/bin/g++-12 \
  -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-12 \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
  -DGGML_CUDA=ON

cmake --build build-cuda -j
```

### Build whisper.cpp (for Speech-to-Text)

```bash
git clone https://github.com/ggml-org/whisper.cpp ~/whisper.cpp
cd ~/whisper.cpp
cmake -B build-cuda -DGGML_CUDA=ON
cmake --build build-cuda -j

# Download the Whisper model (required!)
bash ./models/download-ggml-model.sh base.en

# Verify model exists
ls -la models/ggml-base.en.bin
```

---

## Recommended Models

Based on community benchmarks, these are the best models for DGX Spark:

### Top Tier: Best Quality-to-Speed Ratio

| Model | Size | Gen Speed | Best For |
|-------|------|-----------|----------|
| **gpt-oss-120B MXFP4** | 59 GiB | ~35 t/s | Reasoning, coding, 93.75% AIME25 |
| **Qwen3-Coder-30B-A3B Q8_0** | 30 GiB | ~50 t/s | Code completion, coding agents |
| **gpt-oss-20B MXFP4** | 11 GiB | ~68 t/s | Fast general chat |

### Download Models

**Option A: Using Hugging Face CLI**

```bash
# Install via pipx (Ubuntu 24.04+)
sudo apt install pipx
pipx install huggingface-hub

# Download gpt-oss-120B (best large model)
hf download ggml-org/gpt-oss-120b-GGUF --local-dir ~/models/gpt-oss-120b

# Download Qwen3 Coder
hf download Qwen/Qwen3-Coder-30B-A3B-Instruct-Q8_0-GGUF --local-dir ~/models/qwen3-coder
```

**Option B: Let llama.cpp Download Automatically (Recommended)**

```bash
# llama-server downloads from HuggingFace automatically with -hf flag
./build-cuda/bin/llama-server -hf ggml-org/gpt-oss-120b-GGUF --port 8080 --no-mmap -ngl 99
```

This is the simplest approach - no separate download step needed.

### Key Insight: MXFP4 Quantization

**MXFP4** is specifically optimized for Blackwell architecture. Prefer MXFP4 models over standard Q4_K_M for best performance on DGX Spark.

---

## Benchmarking Your System

### Basic Benchmark

```bash
cd ~/llama.cpp

# Single request benchmark
./build-cuda/bin/llama-bench \
  -m ~/models/gpt-oss-120b/gpt-oss-120b-mxfp4-00001-of-00003.gguf \
  -fa 1 \
  -d 0,4096,8192,16384,32768 \
  -p 2048 \
  -n 32 \
  -ub 2048 \
  --no-mmap
```

**Parameters explained:**
- `-fa 1`: Enable flash attention
- `-d`: Context depths to test (0, 4K, 8K, 16K, 32K tokens)
- `-p 2048`: Prompt/prefill length
- `-n 32`: Generation length
- `-ub 2048`: Micro-batch size
- `--no-mmap`: Disable memory mapping (faster on DGX Spark)

### Parallel Requests Benchmark

```bash
./build-cuda/bin/llama-batched-bench \
  -m ~/models/gpt-oss-120b/gpt-oss-120b-mxfp4-00001-of-00003.gguf \
  -fa 1 \
  -c 300000 \
  -ub 2048 \
  -npp 4096,8192 \
  -ntg 32 \
  -npl 1,2,4,8,16,32 \
  --no-mmap
```

### Expected Results (gpt-oss-120B MXFP4)

| Test | Performance |
|------|-------------|
| pp2048 (prefill) | ~1000 t/s |
| tg32 (generation) | ~35 t/s |
| tg32 @ d32768 | ~30 t/s |

---

## Use Cases & Configuration

### 1. Basic Chat Interface

Start the server and open in browser:

```bash
./build-cuda/bin/llama-server \
  -hf ggml-org/gpt-oss-120b-GGUF \
  --ctx-size 131072 \
  -np 8 \
  --jinja \
  -ub 2048 \
  -b 2048 \
  -ngl 99 \
  --port 8023 \
  --no-mmap
```

Then open: `http://localhost:8023`

### 2. Code Completion (FIM) for IDEs

```bash
./build-cuda/bin/llama-server \
  -hf Qwen/Qwen2.5-Coder-7B-Instruct-GGUF \
  --ctx-size 32768 \
  -ngl 99 \
  --port 8022 \
  --no-mmap
```

**VSCode Setup:**
1. Install `llama.vscode` extension
2. Configure endpoint: `http://localhost:8022`

**Vim/Neovim Setup:**
1. Install `llama.vim` plugin
2. Configure endpoint in your config

### 3. Vision/Multimodal

```bash
./build-cuda/bin/llama-server \
  -hf google/gemma-3-4b-it-qat-q4_0-gguf \
  --ctx-size 8192 \
  -ngl 99 \
  --port 8024 \
  --no-mmap
```

### 4. Embeddings Service

```bash
./build-cuda/bin/llama-server \
  -hf nomic-ai/nomic-embed-text-v2-moe-GGUF \
  --ctx-size 8192 \
  --embedding \
  --port 8021
```

### 5. Network Access (Multi-User)

To allow access from other machines on your network:

```bash
./build-cuda/bin/llama-server \
  -hf ggml-org/gpt-oss-120b-GGUF \
  --host 0.0.0.0 \
  --port 8023 \
  # ... other options
```

Access from other machines: `http://192.168.0.122:8023` (your DGX IP)

---

## Performance Optimization

### Critical Settings for DGX Spark

1. **Always use `--no-mmap`** - Disabling memory mapping significantly improves performance
2. **Use `-ngl 99`** - Offload all layers to GPU
3. **Enable flash attention** - `-fa 1` or `--flash-attn`
4. **Tune batch size** - `-ub 2048` works well for most models

### Optimal Server Configuration

```bash
./build-cuda/bin/llama-server \
  -m /path/to/model.gguf \
  --ctx-size 131072 \
  -np 8 \
  --jinja \
  -ub 2048 \
  -b 2048 \
  -ngl 99 \
  --flash-attn \
  --no-mmap \
  --temp 1.0 \
  --top-p 1.0 \
  --top-k 0 \
  --min-p 0.01 \
  --port 8080
```

### Monitor Performance

```bash
# Watch GPU utilization
watch -n 1 nvidia-smi

# Check memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

---

## Troubleshooting

### Issue: Build Fails with GCC 13 Errors

**Symptoms:**
```
error: identifier "__Float32x4_t" is undefined
```

**Solution:**
```bash
sudo apt install g++-12
# Then rebuild with -DCMAKE_CXX_COMPILER=/usr/bin/g++-12
```

### Issue: CUDA 12 vs CUDA 13 Conflict

**Symptoms:** nvcc shows version 12.x instead of 13.x

**Solution:**
```bash
sudo apt purge nvidia-cuda-toolkit
export PATH="/usr/local/cuda-13/bin:$PATH"
```

### Issue: Missing libcurl

**Symptoms:** cmake can't find CURL

**Solution:**
```bash
sudo apt install libcurl4-openssl-dev
```

### Issue: Slow Model Loading

**Symptoms:** Models take very long to load

**Solution:** Use `--no-mmap` flag - this is especially important on DGX Spark

### Issue: Out of Memory

**Symptoms:** CUDA out of memory errors

**Solution:**
- Reduce context size (`--ctx-size`)
- Use more aggressive quantization (Q4 instead of Q8)
- Reduce parallel slots (`-np`)

---

## Advanced: Using Ollama

If you prefer Ollama's simpler interface:

### Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Pull Models

```bash
# The MXFP4 models may not be available in Ollama
# Use standard quantizations
ollama pull qwen2.5-coder:32b
ollama pull llama3.3:70b-instruct-q4_K_M
```

### Serve with Network Access

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

### Docker with GPU Support

```bash
docker run -d \
  --gpus all \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --name ollama \
  ollama/ollama
```

---

## Quick Reference Card

### Start All Services (ggml way)
```bash
# First time / full reinstall
bash <(curl -s https://ggml.ai/dgx-spark.sh)

# Interactive service manager (select which to start)
~/ggml-services.sh

# Start all services (non-interactive)
~/ggml-services.sh --start-all

# Check status
~/ggml-services.sh --status

# Stop all services
~/ggml-services.sh --stop-all
```

### Service Endpoints
| Service | URL |
|---------|-----|
| Chat | http://localhost:8023 |
| FIM/Code | http://localhost:8022 |
| Embeddings | http://localhost:8021 |
| Vision | http://localhost:8024 |
| Speech-to-Text | http://localhost:8025 |

### Best Models for DGX Spark
- **Large reasoning:** `gpt-oss-120b-mxfp4`
- **Coding:** `Qwen3-Coder-30B-A3B Q8_0`
- **Fast chat:** `gpt-oss-20b-mxfp4`

### Key Flags
```
--no-mmap        # Essential for DGX Spark performance
-ngl 99          # GPU offload all layers
-fa 1            # Flash attention
--host 0.0.0.0   # Network access
```

---

## References

- [Performance Benchmarks](https://github.com/ggml-org/llama.cpp/discussions/16578)
- [Official Setup Guide](https://github.com/ggml-org/llama.cpp/discussions/16514)
- [llama.cpp Repository](https://github.com/ggml-org/llama.cpp)
- [DGX Spark Benchmark Results](https://github.com/ggml-org/llama.cpp/blob/master/benches/dgx-spark.md)

---

*Guide compiled from official ggml documentation and community benchmarks. Last updated: December 2025*
