# Ollama Model Benchmark Report

**Generated:** 2025-12-08 17:23:51

## Machine Specifications

| Spec | Value |
|------|-------|
| **OS** | Darwin 25.1.0 |
| **CPU** | Apple M1 Max |
| **CPU Cores** | 10 |
| **Memory** | 32.0 GB |
| **GPU** | Apple M1 Max |
| **Architecture** | arm64 |
| **Python Version** | 3.14.0 |

## Ollama GPU Status

| Property | Value |
|----------|-------|
| **GPU Available** | Yes |
| **GPU Backend** | Apple Silicon (Metal) |
| **Ollama Using GPU** | Available but not used |
| **GPU/CPU Split** | N/A |

## Summary

- **Total Models Benchmarked:** 3
- **Successful:** 3
- **Failed:** 0

## Benchmark Results

| Model | Status | First Token (ms) | Tokens/Second | Total Time (s) | Token Count |
|-------|--------|------------------|---------------|----------------|-------------|
| gpt-oss:20b | success | 3506.53 | 13.9 | 23.38 | 325 |
| mistral:7b | success | 1139.08 | 5.4 | 7.59 | 41 |
| llama3.1:8b | success | 1546.32 | 4.56 | 10.31 | 47 |

## Fastest by First Token Latency (Top 5)

| Model | First Token (ms) |
|-------|------------------|
| mistral:7b | 1139.08 |
| llama3.1:8b | 1546.32 |
| gpt-oss:20b | 3506.53 |

## Fastest by Throughput (Top 5)

| Model | Tokens/Second |
|-------|---------------|
| gpt-oss:20b | 13.9 |
| mistral:7b | 5.4 |
| llama3.1:8b | 4.56 |

## Notes

- **First Token (ms):** Estimated time to first token (milliseconds)
- **Tokens/Second:** Throughput in tokens per second
- **Total Time (s):** Total benchmark time in seconds
- **Token Count:** Number of tokens in response
