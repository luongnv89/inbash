"""GPU information detection module for Ollama benchmarking."""

import subprocess
import platform


def get_ollama_gpu_info():
    """Get Ollama GPU usage information from 'ollama ps' and system info."""
    gpu_info = {
        "gpu_available": False,
        "gpu_in_use": False,
        "gpu_layers": "N/A",
        "details": "Unknown"
    }

    try:
        # Check if Ollama is running and get loaded models info
        ps_result = subprocess.run(
            ["ollama", "ps"],
            capture_output=True,
            text=True,
            timeout=10
        )

        if ps_result.returncode == 0:
            output = ps_result.stdout.strip()
            lines = output.split('\n')
            if len(lines) > 1:  # Has header + model info
                # Parse the output to check GPU usage
                # Format: NAME ID SIZE PROCESSOR CONTEXT UNTIL
                # The output uses fixed-width columns, so we need to find column positions
                header = lines[0]

                # Find column start positions from header
                processor_start = header.find('PROCESSOR')
                context_start = header.find('CONTEXT')

                if processor_start >= 0:  # PROCESSOR column exists
                    for line in lines[1:]:
                        if line.strip():
                            # Extract PROCESSOR column based on fixed positions
                            if context_start >= 0:
                                processor = line[processor_start:context_start].strip()
                            else:
                                processor = line[processor_start:].strip()

                            # Check if GPU is being used (e.g., "100% GPU" or "50% GPU", etc.)
                            if "GPU" in processor.upper():
                                gpu_info["gpu_in_use"] = True
                                gpu_info["gpu_layers"] = processor
                            elif "CPU" in processor.upper():
                                gpu_info["gpu_layers"] = processor
                else:
                    # Fallback to old split-based parsing if header format is different
                    for line in lines[1:]:
                        if line.strip():
                            parts = line.split()
                            if len(parts) >= 4:
                                processor = parts[3]
                                if "GPU" in processor.upper():
                                    gpu_info["gpu_in_use"] = True
                                    gpu_info["gpu_layers"] = processor
                                elif "CPU" in processor.upper():
                                    gpu_info["gpu_layers"] = processor

        # Check system for GPU availability
        system = platform.system()
        if system == "Darwin":
            # Check for Apple Silicon (Metal support)
            machine = platform.machine()
            if machine == "arm64":
                gpu_info["gpu_available"] = True
                gpu_info["details"] = "Apple Silicon (Metal)"
            else:
                # Intel Mac - check for discrete GPU
                gpu_result = subprocess.run(
                    ["system_profiler", "SPDisplaysDataType"],
                    capture_output=True, text=True
                )
                if "Metal" in gpu_result.stdout:
                    gpu_info["gpu_available"] = True
                    gpu_info["details"] = "Metal supported"

        elif system == "Linux":
            # Check for NVIDIA GPU
            try:
                nvidia_result = subprocess.run(
                    ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
                    capture_output=True, text=True, timeout=5
                )
                if nvidia_result.returncode == 0 and nvidia_result.stdout.strip():
                    gpu_info["gpu_available"] = True
                    gpu_info["details"] = f"NVIDIA: {nvidia_result.stdout.strip()}"
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass

            # Check for AMD ROCm
            if not gpu_info["gpu_available"]:
                try:
                    rocm_result = subprocess.run(
                        ["rocm-smi", "--showproductname"],
                        capture_output=True, text=True, timeout=5
                    )
                    if rocm_result.returncode == 0:
                        gpu_info["gpu_available"] = True
                        gpu_info["details"] = "AMD ROCm"
                except (FileNotFoundError, subprocess.TimeoutExpired):
                    pass

    except Exception as e:
        gpu_info["error"] = str(e)

    return gpu_info
