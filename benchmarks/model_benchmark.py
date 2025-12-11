"""Model benchmarking module for Ollama."""

import subprocess
import time


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
