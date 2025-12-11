#!/usr/bin/env python3
"""
Test script to verify GPU detection parsing works correctly.

This can be run independently to test GPU detection without benchmarking.
"""

import subprocess
import platform


def test_ollama_ps_parsing():
    """Test the ollama ps parsing with a mock output."""
    print("=" * 70)
    print("GPU Detection Test - ollama ps Parsing")
    print("=" * 70)

    # Test with mock output
    mock_output = """NAME            ID              SIZE      PROCESSOR    CONTEXT    UNTIL
mistral:7b      6577803aa9a0    5.1 GB    100% GPU     4096       24 hours from now
gpt-oss:20b     17052f91a42e    14 GB     100% GPU     8192       24 hours from now
gpt-oss:120b    a951a23b46a1    65 GB     100% GPU     8192       24 hours from now"""

    gpu_info = {
        "gpu_available": False,
        "gpu_in_use": False,
        "gpu_layers": "N/A",
        "details": "Unknown"
    }

    lines = mock_output.split('\n')
    if len(lines) > 1:
        header = lines[0]
        processor_start = header.find('PROCESSOR')
        context_start = header.find('CONTEXT')

        print(f"\nHeader Analysis:")
        print(f"  Header: {header}")
        print(f"  PROCESSOR column starts at: {processor_start}")
        print(f"  CONTEXT column starts at: {context_start}")

        if processor_start >= 0:
            print(f"\nParsing Data Rows:")
            for line in lines[1:]:
                if line.strip():
                    if context_start >= 0:
                        processor = line[processor_start:context_start].strip()
                    else:
                        processor = line[processor_start:].strip()

                    model_name = line.split()[0]
                    print(f"  {model_name}: '{processor}'")

                    if "GPU" in processor.upper():
                        gpu_info["gpu_in_use"] = True
                        gpu_info["gpu_layers"] = processor

    print(f"\nResults:")
    print(f"  GPU In Use: {gpu_info['gpu_in_use']}")
    print(f"  GPU Layers: {gpu_info['gpu_layers']}")

    if gpu_info['gpu_in_use']:
        print("\n✓ GPU detection working correctly!")
        return True
    else:
        print("\n✗ GPU detection failed!")
        return False


def test_real_ollama_ps():
    """Test with real ollama ps output if available."""
    print("\n" + "=" * 70)
    print("Real ollama ps Output Test")
    print("=" * 70)

    try:
        result = subprocess.run(
            ["ollama", "ps"],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            print("\nActual ollama ps output:")
            print(result.stdout)

            # Parse it
            gpu_info = {
                "gpu_available": False,
                "gpu_in_use": False,
                "gpu_layers": "N/A",
                "details": "Unknown"
            }

            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                header = lines[0]
                processor_start = header.find('PROCESSOR')
                context_start = header.find('CONTEXT')

                if processor_start >= 0:
                    for line in lines[1:]:
                        if line.strip():
                            if context_start >= 0:
                                processor = line[processor_start:context_start].strip()
                            else:
                                processor = line[processor_start:].strip()

                            if "GPU" in processor.upper():
                                gpu_info["gpu_in_use"] = True
                                gpu_info["gpu_layers"] = processor

            print(f"\nParsed Results:")
            print(f"  GPU In Use: {gpu_info['gpu_in_use']}")
            print(f"  GPU Layers: {gpu_info['gpu_layers']}")

            if gpu_info['gpu_in_use']:
                print("\n✓ Real GPU detection working!")
            else:
                print("\n✓ No models currently loaded (GPU not in use)")

        else:
            print("\nOllama ps returned an error or no output")
            print("(This is normal if no models are currently loaded)")

    except FileNotFoundError:
        print("\nOllama not found in PATH")
    except subprocess.TimeoutExpired:
        print("\nOllama ps timed out")


def test_system_gpu_detection():
    """Test system GPU detection."""
    print("\n" + "=" * 70)
    print("System GPU Detection Test")
    print("=" * 70)

    system = platform.system()
    print(f"\nOperating System: {system}")

    if system == "Linux":
        # Test NVIDIA
        try:
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                print(f"NVIDIA GPU detected: {result.stdout.strip()}")
            else:
                print("No NVIDIA GPU detected (or nvidia-smi not available)")
        except FileNotFoundError:
            print("nvidia-smi not found (NVIDIA GPU not available)")

    elif system == "Darwin":
        machine = platform.machine()
        print(f"Machine: {machine}")
        if machine == "arm64":
            print("✓ Apple Silicon detected - Metal GPU support available")
        else:
            print("Intel Mac - checking for Metal support...")


if __name__ == "__main__":
    print("\nOllama GPU Detection Test Suite\n")

    # Run tests
    test1_passed = test_ollama_ps_parsing()
    test_real_ollama_ps()
    test_system_gpu_detection()

    print("\n" + "=" * 70)
    if test1_passed:
        print("✓ All tests completed successfully!")
    else:
        print("Note: Mock test failed (but real ollama ps may work differently)")
    print("=" * 70)
