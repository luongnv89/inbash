# Benchmarks Module

A modular Python package for benchmarking Ollama models with comprehensive system and GPU information.

## Quick Start

```python
from benchmarks import (
    get_machine_specs,
    get_ollama_gpu_info,
    benchmark_model,
    get_ollama_models,
    generate_markdown_report,
)

# Collect system information
specs = get_machine_specs()
gpu_info = get_ollama_gpu_info()

# Get and benchmark models
models = get_ollama_models()
results = []
for model in models:
    result = benchmark_model(model, "Your test prompt")
    results.append(result)

# Generate report
generate_markdown_report(results, specs, gpu_info, "benchmark_results.md")
```

## Module Overview

| Module | Purpose |
|--------|---------|
| `machine_specs.py` | Detect CPU, memory, GPU, and OS information |
| `gpu_info.py` | Check GPU availability and Ollama GPU usage |
| `model_benchmark.py` | Run benchmarks on Ollama models |
| `report.py` | Generate formatted markdown reports |

## API Reference

### `get_machine_specs()`
Returns a dictionary with system specifications:
- `os`: Operating system name
- `os_release`: OS release version
- `cpu`: CPU model name
- `cpu_cores`: Number of CPU cores
- `memory_gb`: RAM in gigabytes
- `gpu`: GPU model
- `machine`: Architecture (arm64, x86_64, etc.)
- `python_version`: Python version

### `get_ollama_gpu_info()`
Returns a dictionary with GPU information:
- `gpu_available`: Boolean - GPU hardware is available
- `gpu_in_use`: Boolean - Ollama is actively using GPU
- `gpu_layers`: String - GPU/CPU split information
- `details`: String - GPU backend details

### `benchmark_model(model_name, prompt, timeout=300)`
Benchmarks a single model. Returns a dictionary:
- `model`: Model name
- `status`: "success", "timeout", or "error"
- `first_token_time_ms`: Estimated first token latency
- `tokens_per_second`: Throughput metric
- `total_time_s`: Total benchmark duration
- `token_count`: Number of tokens in response
- `error`: Error message (if applicable)

### `get_ollama_models()`
Returns a list of available model names from `ollama ls`.

### `generate_markdown_report(results, machine_specs, ollama_gpu_info, output_file)`
Generates a markdown report file with:
- System specifications table
- GPU status information
- Benchmark results table
- Top 5 fastest by latency
- Top 5 fastest by throughput

## Platform Support

- **macOS**: Apple Silicon (arm64) and Intel with Metal support
- **Linux**: NVIDIA GPUs (via nvidia-smi) and AMD ROCm

## Requirements

- Python 3.6+
- Ollama installed and in PATH
- System tools: `sysctl` (macOS), `/proc` filesystem (Linux), `nvidia-smi` (for NVIDIA GPUs)
