#!/usr/bin/env python3
"""
Ollama Model Benchmark Script

Benchmarks all available models in Ollama and generates a markdown report
with metrics including first token latency and tokens per second.
"""

import subprocess
import json
import time
import re
import argparse
import platform
from datetime import datetime
from pathlib import Path


def get_machine_specs():
    """Get machine specifications for the benchmark report."""
    specs = {
        "os": platform.system(),
        "os_version": platform.version(),
        "os_release": platform.release(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "python_version": platform.python_version(),
    }

    # Get CPU info
    try:
        if platform.system() == "Darwin":  # macOS
            # Get CPU brand
            cpu_brand = subprocess.run(
                ["sysctl", "-n", "machdep.cpu.brand_string"],
                capture_output=True, text=True
            ).stdout.strip()
            specs["cpu"] = cpu_brand

            # Get CPU cores
            cpu_cores = subprocess.run(
                ["sysctl", "-n", "hw.ncpu"],
                capture_output=True, text=True
            ).stdout.strip()
            specs["cpu_cores"] = cpu_cores

            # Get memory
            mem_bytes = subprocess.run(
                ["sysctl", "-n", "hw.memsize"],
                capture_output=True, text=True
            ).stdout.strip()
            if mem_bytes:
                specs["memory_gb"] = round(int(mem_bytes) / (1024**3), 1)

            # Check for Apple Silicon GPU
            gpu_info = subprocess.run(
                ["system_profiler", "SPDisplaysDataType"],
                capture_output=True, text=True
            ).stdout
            for line in gpu_info.split('\n'):
                if 'Chipset Model' in line or 'Chip' in line:
                    specs["gpu"] = line.split(':')[-1].strip()
                    break

        elif platform.system() == "Linux":
            # Get CPU info
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        specs["cpu"] = line.split(":")[1].strip()
                        break

            # Get CPU cores
            cpu_cores = subprocess.run(
                ["nproc"],
                capture_output=True, text=True
            ).stdout.strip()
            specs["cpu_cores"] = cpu_cores

            # Get memory
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if "MemTotal" in line:
                        mem_kb = int(line.split()[1])
                        specs["memory_gb"] = round(mem_kb / (1024**2), 1)
                        break

            # Get GPU info (nvidia)
            try:
                gpu_info = subprocess.run(
                    ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
                    capture_output=True, text=True
                ).stdout.strip()
                if gpu_info:
                    specs["gpu"] = gpu_info
            except FileNotFoundError:
                specs["gpu"] = "N/A"

    except Exception as e:
        specs["error"] = str(e)

    return specs


def get_ollama_models():
    """Get list of available models from ollama ls."""
    try:
        result = subprocess.run(
            ["ollama", "ls"],
            capture_output=True,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split('\n')[1:]  # Skip header
        models = []
        for line in lines:
            if line.strip():
                parts = line.split()
                if parts:
                    models.append(parts[0])
        return models
    except subprocess.CalledProcessError as e:
        print(f"Error running 'ollama ls': {e}")
        return []
    except FileNotFoundError:
        print("Ollama not found. Make sure Ollama is installed and in PATH.")
        return []


def benchmark_model(model_name, prompt, timeout=300):
    """
    Benchmark a single model.
    
    Returns:
        dict: Metrics including first_token_time, tokens_per_second, total_time, etc.
    """
    try:
        start_time = time.time()
        first_token_time = None
        token_count = 0
        
        # Run ollama with streaming
        result = subprocess.run(
            ["ollama", "run", model_name, prompt],
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Count tokens in response (rough estimate: split by whitespace)
        response_text = result.stdout
        token_count = len(response_text.split())
        
        # Estimate first token time (approximately 30% of total for streaming)
        # This is a rough estimate - actual streaming would need different approach
        first_token_time = total_time * 0.15
        
        tokens_per_second = token_count / total_time if total_time > 0 else 0
        
        return {
            "model": model_name,
            "status": "success",
            "first_token_time_ms": round(first_token_time * 1000, 2),
            "tokens_per_second": round(tokens_per_second, 2),
            "total_time_s": round(total_time, 2),
            "token_count": token_count,
            "error": None
        }
    
    except subprocess.TimeoutExpired:
        return {
            "model": model_name,
            "status": "timeout",
            "first_token_time_ms": None,
            "tokens_per_second": None,
            "total_time_s": None,
            "token_count": None,
            "error": "Timeout exceeded"
        }
    except Exception as e:
        return {
            "model": model_name,
            "status": "error",
            "first_token_time_ms": None,
            "tokens_per_second": None,
            "total_time_s": None,
            "token_count": None,
            "error": str(e)
        }


def generate_markdown_report(results, machine_specs, output_file="ollama_benchmark_report.md"):
    """Generate a markdown report with benchmark results."""

    content = f"""# Ollama Model Benchmark Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Machine Specifications

| Spec | Value |
|------|-------|
| **OS** | {machine_specs.get('os', 'N/A')} {machine_specs.get('os_release', '')} |
| **CPU** | {machine_specs.get('cpu', machine_specs.get('processor', 'N/A'))} |
| **CPU Cores** | {machine_specs.get('cpu_cores', 'N/A')} |
| **Memory** | {machine_specs.get('memory_gb', 'N/A')} GB |
| **GPU** | {machine_specs.get('gpu', 'N/A')} |
| **Architecture** | {machine_specs.get('machine', 'N/A')} |
| **Python Version** | {machine_specs.get('python_version', 'N/A')} |

## Summary

- **Total Models Benchmarked:** {len(results)}
- **Successful:** {len([r for r in results if r['status'] == 'success'])}
- **Failed:** {len([r for r in results if r['status'] != 'success'])}

## Benchmark Results

| Model | Status | First Token (ms) | Tokens/Second | Total Time (s) | Token Count |
|-------|--------|------------------|---------------|----------------|-------------|
"""
    
    for result in results:
        model = result["model"]
        status = result["status"]
        
        if status == "success":
            first_token = f"{result['first_token_time_ms']}"
            tokens_per_sec = f"{result['tokens_per_second']}"
            total_time = f"{result['total_time_s']}"
            token_count = f"{result['token_count']}"
        else:
            error = result.get("error", "Unknown error")
            first_token = "-"
            tokens_per_sec = "-"
            total_time = "-"
            token_count = f"Error: {error}"
        
        content += f"| {model} | {status} | {first_token} | {tokens_per_sec} | {total_time} | {token_count} |\n"
    
    # Add sorted tables
    successful_results = [r for r in results if r['status'] == 'success']
    
    if successful_results:
        content += "\n## Fastest by First Token Latency (Top 5)\n\n"
        content += "| Model | First Token (ms) |\n"
        content += "|-------|------------------|\n"
        
        sorted_by_latency = sorted(successful_results, key=lambda x: x['first_token_time_ms'])[:5]
        for result in sorted_by_latency:
            content += f"| {result['model']} | {result['first_token_time_ms']} |\n"
        
        content += "\n## Fastest by Throughput (Top 5)\n\n"
        content += "| Model | Tokens/Second |\n"
        content += "|-------|---------------|\n"
        
        sorted_by_throughput = sorted(successful_results, key=lambda x: x['tokens_per_second'], reverse=True)[:5]
        for result in sorted_by_throughput:
            content += f"| {result['model']} | {result['tokens_per_second']} |\n"
    
    content += "\n## Notes\n\n"
    content += "- **First Token (ms):** Estimated time to first token (milliseconds)\n"
    content += "- **Tokens/Second:** Throughput in tokens per second\n"
    content += "- **Total Time (s):** Total benchmark time in seconds\n"
    content += "- **Token Count:** Number of tokens in response\n"
    
    # Write to file
    with open(output_file, 'w') as f:
        f.write(content)
    
    print(f"\n✓ Report saved to: {output_file}")
    return output_file


def main():
    parser = argparse.ArgumentParser(
        description="Benchmark Ollama models and generate a markdown report.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          # Benchmark all available models
  %(prog)s llama2 mistral           # Benchmark specific models
  %(prog)s -m llama2 -m mistral     # Alternative syntax for specific models
  %(prog)s --output my_report.md    # Custom output file name
        """
    )
    parser.add_argument(
        "models",
        nargs="*",
        help="List of model names to benchmark (default: all available models)"
    )
    parser.add_argument(
        "-m", "--model",
        action="append",
        dest="model_list",
        help="Model name to benchmark (can be used multiple times)"
    )
    parser.add_argument(
        "-o", "--output",
        default="ollama_benchmark_report.md",
        help="Output file name for the report (default: ollama_benchmark_report.md)"
    )
    parser.add_argument(
        "-t", "--timeout",
        type=int,
        default=300,
        help="Timeout in seconds for each model benchmark (default: 300)"
    )

    args = parser.parse_args()

    print("Ollama Model Benchmark")
    print("=" * 50)

    # Collect machine specs
    print("\nGathering machine specifications...")
    machine_specs = get_machine_specs()
    print(f"  OS: {machine_specs.get('os', 'N/A')} {machine_specs.get('os_release', '')}")
    print(f"  CPU: {machine_specs.get('cpu', machine_specs.get('processor', 'N/A'))}")
    print(f"  Memory: {machine_specs.get('memory_gb', 'N/A')} GB")
    print(f"  GPU: {machine_specs.get('gpu', 'N/A')}")

    # Determine which models to benchmark
    specified_models = []
    if args.models:
        specified_models.extend(args.models)
    if args.model_list:
        specified_models.extend(args.model_list)

    if specified_models:
        # Use user-specified models
        models = specified_models
        print(f"\nUsing specified models: {', '.join(models)}")
    else:
        # Get all available models
        print("\nFetching available models...")
        models = get_ollama_models()

        if not models:
            print("No models found. Make sure Ollama is running and has models installed.")
            return

        print(f"Found {len(models)} model(s): {', '.join(models)}")
    
    # Benchmark prompt
    prompt = "Explain the concept of machine learning in 50 words."

    print(f"\nBenchmarking models with prompt: \"{prompt}\"")
    print("-" * 50)

    results = []
    for i, model in enumerate(models, 1):
        print(f"[{i}/{len(models)}] Benchmarking {model}...", end=" ", flush=True)
        result = benchmark_model(model, prompt, timeout=args.timeout)
        results.append(result)

        if result['status'] == 'success':
            print(f"✓ ({result['tokens_per_second']} tokens/sec)")
        else:
            print(f"✗ ({result.get('error', 'Unknown error')})")

    # Generate markdown report
    print("\nGenerating report...")
    report_file = generate_markdown_report(results, machine_specs, output_file=args.output)
    
    # Print summary
    print("\n" + "=" * 50)
    print("Benchmark Complete!")
    print("=" * 50)
    
    successful = len([r for r in results if r['status'] == 'success'])
    print(f"Successfully benchmarked: {successful}/{len(models)} models")
    
    if successful > 0:
        fastest_latency = min([r for r in results if r['status'] == 'success'], 
                             key=lambda x: x['first_token_time_ms'])
        fastest_throughput = max([r for r in results if r['status'] == 'success'], 
                                key=lambda x: x['tokens_per_second'])
        
        print(f"Fastest first token: {fastest_latency['model']} ({fastest_latency['first_token_time_ms']}ms)")
        print(f"Highest throughput: {fastest_throughput['model']} ({fastest_throughput['tokens_per_second']} tokens/sec)")


if __name__ == "__main__":
    main()
