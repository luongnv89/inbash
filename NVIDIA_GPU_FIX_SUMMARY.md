# NVIDIA GPU Detection Fix Summary

## Issue
When benchmarking on NVIDIA DGX Spark systems, the report incorrectly showed **"Ollama Using GPU: No"** even though the GPU was actively being used (confirmed by `ollama ps` showing `100% GPU`).

## Root Cause Analysis

The GPU detection code had **two critical issues**:

### Issue #1: Incorrect Parsing of `ollama ps` Output
The original code used simple whitespace splitting:
```python
parts = line.split()
processor = parts[3]  # This gets the wrong column!
```

With the actual output format:
```
NAME            ID              SIZE      PROCESSOR    CONTEXT    UNTIL
mistral:7b      6577803aa9a0    5.1 GB    100% GPU     4096       24 hours from now
```

The split produces: `["mistral:7b", "6577803aa9a0", "5.1", "GB", "100%", "GPU", ...]`

So `parts[3]` returns `"GB"` instead of `"100% GPU"`, causing GPU detection to fail.

### Issue #2: Timing of GPU Status Check
The GPU info was checked **before** any benchmarking started, when no models were loaded, so `ollama ps` returned an empty list. The status was only checked after the first model, but not properly reflected in the final report.

## Solution Implemented

### 1. Fixed Column-Based Parsing (Primary Fix)
Replaced simple whitespace splitting with **column-position-based parsing** that respects the fixed-width column format:

```python
# Find column positions from header
processor_start = header.find('PROCESSOR')
context_start = header.find('CONTEXT')

# Extract using fixed positions
processor = line[processor_start:context_start].strip()
# This correctly extracts "100% GPU"
```

**Benefits:**
- Works with multi-word values in columns (e.g., "5.1 GB")
- Resilient to different column widths
- Handles GPU info like "50% GPU, 50% CPU" correctly
- Includes fallback for other output formats

### 2. Final GPU Status Check (Secondary Fix)
Added a final GPU status check after all benchmarking completes:

```python
# Final GPU status check after benchmarking (models are still loaded)
final_gpu_info = get_ollama_gpu_info()
if final_gpu_info.get('gpu_in_use'):
    ollama_gpu_info = final_gpu_info
```

**Benefits:**
- Captures GPU usage while models are actually loaded
- Ensures the report reflects real GPU usage during benchmarking
- Updates report with accurate GPU information

## Files Modified

1. **`benchmarks/gpu_info.py`**
   - Replaced whitespace-based parsing with column-position-based parsing
   - Added fallback mechanism for compatibility
   - Improved comments documenting the output format

2. **`ollama_benchmark.py`**
   - Added final GPU status check after benchmarking loop
   - Uses detected GPU usage in final report

## Testing

The fix was validated with:

1. **Mock Data Test**: Simulating your NVIDIA DGX Spark `ollama ps` output
   ```
   mistral:7b      6577803aa9a0    5.1 GB    100% GPU     4096       24 hours from now
   gpt-oss:20b     17052f91a42e    14 GB     100% GPU     8192       24 hours from now
   gpt-oss:120b    a951a23b46a1    65 GB     100% GPU     8192       24 hours from now
   ```
   **Result**: ✓ Correctly detected as `100% GPU`

2. **Real System Test**: Verified parsing logic works with actual `ollama ps` output

3. **Backward Compatibility**: Verified existing functionality for macOS/Apple Silicon still works

## Expected Report Output

After the fix, your benchmark report should now show:

```markdown
## Ollama GPU Status

| Property | Value |
|----------|-------|
| **GPU Available** | Yes |
| **GPU Backend** | NVIDIA: [Your GPU Model] |
| **Ollama Using GPU** | Yes |
| **GPU/CPU Split** | 100% GPU |
```

Instead of the previous incorrect:

```markdown
## Ollama GPU Status

| Property | Value |
|----------|-------|
| **GPU Available** | Yes |
| **GPU Backend** | NVIDIA: [Your GPU Model] |
| **Ollama Using GPU** | No |
| **GPU/CPU Split** | N/A |
```

## Compatibility

- ✓ NVIDIA GPUs (DGX, CUDA)
- ✓ Apple Silicon (Metal)
- ✓ AMD ROCm
- ✓ CPU-only systems
- ✓ Mixed GPU/CPU workloads

## How to Verify the Fix

Run the provided test script:
```bash
python3 test_gpu_detection.py
```

Or run a normal benchmark and check the generated report for correct GPU status.

## Technical Details

The `ollama ps` output uses fixed-width columns:
```
Column          Start Position
NAME            0
ID              16
SIZE            32
PROCESSOR       42
CONTEXT         55
UNTIL           66
```

The new code finds these positions dynamically from the header line and uses them to extract values, ensuring accuracy regardless of the data content.
