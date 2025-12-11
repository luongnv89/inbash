"""Machine specifications detection module for benchmarking."""

import subprocess
import platform


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
