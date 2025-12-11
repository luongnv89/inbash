# Ollama Benchmarks Module Structure

## Overview

The Ollama benchmark functionality has been refactored into a separate, modular package called `benchmarks`. This improves code organization, reusability, and maintainability.

## Directory Structure

```
inbash/
├── ollama_benchmark.py          # Main entry point (refactored)
└── benchmarks/                  # New benchmark module
    ├── __init__.py              # Package initialization with exports
    ├── machine_specs.py         # Machine specification detection
    ├── gpu_info.py              # GPU information detection
    ├── model_benchmark.py       # Model benchmarking logic
    └── report.py                # Report generation
```

## Module Descriptions

### `benchmarks/__init__.py`
Package initialization file that exports the main functions for easy importing.

**Exports:**
- `get_machine_specs()` - Get system specifications
- `get_ollama_gpu_info()` - Get GPU availability and usage info
- `benchmark_model()` - Benchmark a single model
- `get_ollama_models()` - Get available Ollama models
- `generate_markdown_report()` - Generate benchmark report

### `benchmarks/machine_specs.py`
Detects and collects machine specifications including OS, CPU, memory, and GPU information.

**Functions:**
- `get_machine_specs()` - Returns a dictionary with machine specifications

### `benchmarks/gpu_info.py`
Detects GPU availability and Ollama's GPU usage across different platforms (macOS, Linux).

**Functions:**
- `get_ollama_gpu_info()` - Returns GPU information including availability, in-use status, and backend details

### `benchmarks/model_benchmark.py`
Handles the actual benchmarking of Ollama models.

**Functions:**
- `get_ollama_models()` - Retrieves list of available models from `ollama ls`
- `benchmark_model(model_name, prompt, timeout)` - Benchmarks a single model and returns metrics

### `benchmarks/report.py`
Generates markdown-formatted benchmark reports.

**Functions:**
- `generate_markdown_report(results, machine_specs, ollama_gpu_info, output_file)` - Creates a formatted markdown report file

## Usage

### As a Package (Recommended)

```python
from benchmarks import (
    get_machine_specs,
    get_ollama_gpu_info,
    benchmark_model,
    get_ollama_models,
    generate_markdown_report,
)

# Get machine specs
specs = get_machine_specs()

# Check GPU info
gpu_info = get_ollama_gpu_info()

# Get available models
models = get_ollama_models()

# Benchmark a model
result = benchmark_model("llama2", "Your prompt here", timeout=300)

# Generate report
generate_markdown_report(results, specs, gpu_info, "report.md")
```

### Via Main Script

```bash
# Benchmark all models
python3 ollama_benchmark.py

# Benchmark specific models
python3 ollama_benchmark.py llama2 mistral

# Benchmark with custom output
python3 ollama_benchmark.py --output my_report.md

# Benchmark with custom timeout
python3 ollama_benchmark.py --timeout 600
```

## Benefits

1. **Modularity** - Each component has a single responsibility
2. **Reusability** - Functions can be imported and used independently
3. **Testability** - Easier to unit test individual modules
4. **Maintainability** - Clearer code organization and easier to modify
5. **Extensibility** - Simple to add new features or benchmark types
6. **Code Organization** - Related functionality grouped together

## Migration Notes

The main `ollama_benchmark.py` script remains the same from a user perspective, but now uses the modular components internally. All existing functionality is preserved.
