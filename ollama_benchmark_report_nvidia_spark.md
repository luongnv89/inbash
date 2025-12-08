# Ollama Model Benchmark Report

**Generated:** 2025-12-08 17:25:13

## Machine Specifications

| Spec | Value |
|------|-------|
| **OS** | Linux 6.14.0-1013-nvidia |
| **CPU** | aarch64 |
| **CPU Cores** | 20 |
| **Memory** | 119.7 GB |
| **GPU** | NVIDIA GB10 |
| **Architecture** | aarch64 |
| **Python Version** | 3.12.3 |

## Ollama GPU Status

| Property | Value |
|----------|-------|
| **GPU Available** | Yes |
| **GPU Backend** | NVIDIA: NVIDIA GB10, [N/A] |
| **Ollama Using GPU** | Available but not used |
| **GPU/CPU Split** | N/A |

## Summary

- **Total Models Benchmarked:** 6
- **Successful:** 6
- **Failed:** 0

## Benchmark Results

| Model | Status | First Token (ms) | Tokens/Second | Total Time (s) | Token Count |
|-------|--------|------------------|---------------|----------------|-------------|
| qwen3:32b | success | 5416.34 | 6.2 | 36.11 | 224 |
| gemma3:27b | success | 1469.86 | 4.59 | 9.8 | 45 |
| mistral:7b | success | 186.62 | 32.15 | 1.24 | 40 |
| llama3.1:8b | success | 696.25 | 10.34 | 4.64 | 48 |
| gpt-oss:120b | success | 5025.58 | 10.75 | 33.5 | 360 |
| gpt-oss:20b | success | 1031.91 | 27.62 | 6.88 | 190 |

## Fastest by First Token Latency (Top 5)

| Model | First Token (ms) |
|-------|------------------|
| mistral:7b | 186.62 |
| llama3.1:8b | 696.25 |
| gpt-oss:20b | 1031.91 |
| gemma3:27b | 1469.86 |
| gpt-oss:120b | 5025.58 |

## Fastest by Throughput (Top 5)

| Model | Tokens/Second |
|-------|---------------|
| mistral:7b | 32.15 |
| gpt-oss:20b | 27.62 |
| gpt-oss:120b | 10.75 |
| llama3.1:8b | 10.34 |
| qwen3:32b | 6.2 |

## Notes

- **First Token (ms):** Estimated time to first token (milliseconds)
- **Tokens/Second:** Throughput in tokens per second
- **Total Time (s):** Total benchmark time in seconds
- **Token Count:** Number of tokens in response