# GPU Detection Fix - NVIDIA DGX Spark

## Problem

The GPU detection was reporting "No" for GPU usage on NVIDIA DGX Spark systems, even though models were clearly being executed on GPU (as seen from `ollama ps` output showing `100% GPU`).

## Root Causes

1. **Parsing Issue**: The original code used simple whitespace splitting (`split()`) to parse `ollama ps` output. However, the `SIZE` column contains values like `5.1 GB` with spaces, which broke the parsing:
   ```
   # Wrong parsing:
   parts = line.split()  # ["mistral:7b", "6577803aa9a0", "5.1", "GB", "100%", "GPU", ...]
   processor = parts[3]  # Returns "GB" instead of "100% GPU"
   ```

2. **Timing Issue**: The initial GPU check happened before any models were loaded, so `ollama ps` returned an empty list. The GPU status was only checked after the first model loaded, but not used in the final report.

## Solution

### 1. Fixed Parsing Logic
Changed from simple whitespace splitting to **column-position-based parsing** that respects the fixed-width column format of `ollama ps`:

```python
# Find column positions from header
processor_start = header.find('PROCESSOR')
context_start = header.find('CONTEXT')

# Extract using fixed positions
processor = line[processor_start:context_start].strip()
```

This correctly extracts `100% GPU` from the PROCESSOR column.

### 2. Final GPU Status Check
Added a final GPU status check after all benchmarking completes (when models are still loaded):

```python
# Final GPU status check after benchmarking (models are still loaded)
print("\nFinal GPU status check...")
final_gpu_info = get_ollama_gpu_info()
if final_gpu_info.get('gpu_in_use'):
    ollama_gpu_info = final_gpu_info
```

This ensures the report reflects actual GPU usage during benchmarking.

## Changes Made

### `benchmarks/gpu_info.py`
- Implemented column-position-based parsing instead of whitespace splitting
- Added fallback to old parsing method for compatibility
- Now correctly extracts GPU information from `ollama ps` output

### `ollama_benchmark.py`
- Added final GPU status check after benchmarking completes
- Uses the detected GPU usage in the final report

## Testing

The fix was tested with actual NVIDIA DGX Spark output:
```
NAME            ID              SIZE      PROCESSOR    CONTEXT    UNTIL
mistral:7b      6577803aa9a0    5.1 GB    100% GPU     4096       24 hours from now
gpt-oss:20b     17052f91a42e    14 GB     100% GPU     8192       24 hours from now
gpt-oss:120b    a951a23b46a1    65 GB     100% GPU     8192       24 hours from now
```

Result: ✓ GPU correctly detected as "100% GPU"

## Expected Behavior After Fix

1. Initial GPU check shows "NVIDIA" GPU available
2. After first model benchmark, GPU usage is detected
3. Final report shows:
   - **GPU Available**: Yes
   - **GPU Backend**: NVIDIA: [GPU info]
   - **Ollama Using GPU**: Yes
   - **GPU/CPU Split**: 100% GPU (or appropriate percentage)

## Compatibility

The fix maintains backward compatibility:
- Falls back to whitespace splitting if column headers are not found
- Works with different `ollama ps` output formats
- No breaking changes to the API

## Files Modified

1. `/benchmarks/gpu_info.py` - Fixed parsing logic
2. `/ollama_benchmark.py` - Added final GPU status check
