#!/usr/bin/env python3
"""
Example usage of the benchmarks module.

This script demonstrates how to use the different functions
from the benchmarks package independently.
"""

from benchmarks import (
    get_machine_specs,
    get_ollama_gpu_info,
    benchmark_model,
    get_ollama_models,
    generate_markdown_report,
)


def example_get_system_info():
    """Example: Get and display system information."""
    print("=" * 60)
    print("Example 1: System Information")
    print("=" * 60)

    specs = get_machine_specs()
    print("\nMachine Specifications:")
    for key, value in specs.items():
        print(f"  {key}: {value}")


def example_get_gpu_info():
    """Example: Check GPU availability."""
    print("\n" + "=" * 60)
    print("Example 2: GPU Information")
    print("=" * 60)

    gpu_info = get_ollama_gpu_info()
    print("\nGPU Status:")
    print(f"  GPU Available: {gpu_info.get('gpu_available')}")
    print(f"  GPU In Use: {gpu_info.get('gpu_in_use')}")
    print(f"  GPU Backend: {gpu_info.get('details')}")
    print(f"  GPU/CPU Split: {gpu_info.get('gpu_layers')}")


def example_get_models():
    """Example: List available models."""
    print("\n" + "=" * 60)
    print("Example 3: Available Models")
    print("=" * 60)

    models = get_ollama_models()
    if models:
        print(f"\nFound {len(models)} model(s):")
        for model in models:
            print(f"  - {model}")
    else:
        print("\nNo models found. Make sure Ollama is running.")


def example_benchmark_single_model():
    """Example: Benchmark a single model."""
    print("\n" + "=" * 60)
    print("Example 4: Benchmark Single Model")
    print("=" * 60)

    models = get_ollama_models()
    if not models:
        print("\nNo models available to benchmark.")
        return

    model_name = models[0]
    prompt = "What is machine learning?"

    print(f"\nBenchmarking: {model_name}")
    print(f"Prompt: {prompt}")

    result = benchmark_model(model_name, prompt, timeout=60)

    print("\nResults:")
    for key, value in result.items():
        print(f"  {key}: {value}")


def example_benchmark_and_report():
    """Example: Benchmark models and generate a report."""
    print("\n" + "=" * 60)
    print("Example 5: Benchmark and Generate Report")
    print("=" * 60)

    specs = get_machine_specs()
    gpu_info = get_ollama_gpu_info()
    models = get_ollama_models()

    if not models:
        print("\nNo models available to benchmark.")
        return

    print(f"\nBenchmarking {len(models)} model(s)...")
    results = []

    for i, model in enumerate(models, 1):
        print(f"  [{i}/{len(models)}] {model}...", end=" ", flush=True)
        result = benchmark_model(model, "Explain AI in 20 words", timeout=60)
        results.append(result)
        print(f"{'✓' if result['status'] == 'success' else '✗'}")

    # Generate report
    output_file = "example_benchmark_report.md"
    print(f"\nGenerating report: {output_file}")
    generate_markdown_report(results, specs, gpu_info, output_file=output_file)


if __name__ == "__main__":
    print("\nOllama Benchmarks Module Examples\n")

    # Run examples
    example_get_system_info()
    example_get_gpu_info()
    example_get_models()

    # Uncomment to run benchmark examples (these take time):
    # example_benchmark_single_model()
    # example_benchmark_and_report()

    print("\n" + "=" * 60)
    print("Examples completed!")
    print("=" * 60)
