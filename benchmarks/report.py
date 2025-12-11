"""Report generation module for Ollama benchmarks."""

from datetime import datetime


def generate_markdown_report(results, machine_specs, ollama_gpu_info, output_file="ollama_benchmark_report.md"):
    """Generate a markdown report with benchmark results."""

    # Determine GPU status for Ollama
    gpu_status = "Yes" if ollama_gpu_info.get('gpu_in_use') else "No"
    if ollama_gpu_info.get('gpu_available') and not ollama_gpu_info.get('gpu_in_use'):
        gpu_status = "Available but not used"

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

## Ollama GPU Status

| Property | Value |
|----------|-------|
| **GPU Available** | {"Yes" if ollama_gpu_info.get('gpu_available') else "No"} |
| **GPU Backend** | {ollama_gpu_info.get('details', 'N/A')} |
| **Ollama Using GPU** | {gpu_status} |
| **GPU/CPU Split** | {ollama_gpu_info.get('gpu_layers', 'N/A')} |

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
