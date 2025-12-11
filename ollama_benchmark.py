#!/usr/bin/env python3
"""
Ollama Model Benchmark Script

Benchmarks all available models in Ollama and generates a markdown report
with metrics including first token latency and tokens per second.
"""

import argparse
from benchmarks import (
    get_machine_specs,
    get_ollama_gpu_info,
    benchmark_model,
    get_ollama_models,
    generate_markdown_report,
)


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

    # Check Ollama GPU status
    print("\nChecking Ollama GPU status...")
    ollama_gpu_info = get_ollama_gpu_info()
    gpu_status = "Yes" if ollama_gpu_info.get('gpu_in_use') else "No"
    if ollama_gpu_info.get('gpu_available') and not ollama_gpu_info.get('gpu_in_use'):
        gpu_status = "Available (checking after first model load)"
    print(f"  GPU Available: {'Yes' if ollama_gpu_info.get('gpu_available') else 'No'}")
    print(f"  GPU Backend: {ollama_gpu_info.get('details', 'N/A')}")

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

        # After first successful benchmark, re-check GPU status (model is now loaded)
        if i == 1 and result['status'] == 'success':
            ollama_gpu_info = get_ollama_gpu_info()
            if ollama_gpu_info.get('gpu_in_use'):
                print(f"  -> GPU acceleration: Active ({ollama_gpu_info.get('gpu_layers', 'N/A')})")
            elif ollama_gpu_info.get('gpu_available'):
                print(f"  -> GPU acceleration: Not used (CPU only)")

    # Final GPU status check after benchmarking (models are still loaded)
    print("\nFinal GPU status check...")
    final_gpu_info = get_ollama_gpu_info()
    if final_gpu_info.get('gpu_in_use'):
        print(f"  GPU in use: {final_gpu_info.get('gpu_layers', 'N/A')}")
    # Use the final GPU info if we detected usage, otherwise use the earlier info
    if final_gpu_info.get('gpu_in_use'):
        ollama_gpu_info = final_gpu_info

    # Generate markdown report
    print("\nGenerating report...")
    report_file = generate_markdown_report(results, machine_specs, ollama_gpu_info, output_file=args.output)
    
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
