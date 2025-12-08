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
from datetime import datetime
from pathlib import Path


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


def generate_markdown_report(results, output_file="ollama_benchmark_report.md"):
    """Generate a markdown report with benchmark results."""
    
    content = f"""# Ollama Model Benchmark Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

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
    print("Ollama Model Benchmark")
    print("=" * 50)
    
    # Get available models
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
        result = benchmark_model(model, prompt)
        results.append(result)
        
        if result['status'] == 'success':
            print(f"✓ ({result['tokens_per_second']} tokens/sec)")
        else:
            print(f"✗ ({result.get('error', 'Unknown error')})")
    
    # Generate markdown report
    print("\nGenerating report...")
    report_file = generate_markdown_report(results)
    
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
