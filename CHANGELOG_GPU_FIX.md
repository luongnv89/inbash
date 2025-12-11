# Changelog - GPU Detection Fix for NVIDIA Systems

## Version 1.1 (GPU Detection Fix)

### Fixed Issues
- **NVIDIA GPU Detection**: Fixed incorrect GPU detection on NVIDIA DGX Spark systems where GPU usage was reported as "No" despite `ollama ps` showing `100% GPU`
- **Parsing Bug**: Corrected `ollama ps` output parsing that was splitting on whitespace and missing the PROCESSOR column due to multi-word values like "5.1 GB"
- **Report Accuracy**: Added final GPU status check to ensure benchmarks accurately reflect GPU usage in reports

### Changes

#### `benchmarks/gpu_info.py`
- **Changed**: Replaced whitespace-based column parsing with column-position-based parsing
- **Added**: Dynamic column position detection from header line
- **Added**: Fallback to whitespace parsing for format compatibility
- **Improved**: Comments documenting `ollama ps` output format
- **Impact**: Now correctly detects `100% GPU`, `50% GPU`, and mixed workloads on NVIDIA systems

#### `ollama_benchmark.py`
- **Added**: Final GPU status check after benchmarking completes (line 123-130)
- **Changed**: Report generation now uses GPU status captured after models are loaded
- **Impact**: Report accurately reflects GPU usage observed during actual benchmarking

#### `tests/test_gpu_detection.py` (NEW)
- **Added**: Comprehensive test suite for GPU detection
- **Includes**: Mock data test, real `ollama ps` test, system GPU detection test
- **Usage**: `python3 test_gpu_detection.py`

#### Documentation (NEW)
- **Added**: `GPU_DETECTION_FIX.md` - Detailed technical explanation
- **Added**: `NVIDIA_GPU_FIX_SUMMARY.md` - Summary of issues and fixes
- **Added**: This changelog

### Technical Details

**Problem Example**:
```
Input line:  mistral:7b    6577803aa9a0    5.1 GB    100% GPU    4096    24 hours from now
Old parsing: parts[3] = "GB"  ❌ (whitespace split breaks multi-word columns)
New parsing: processor = "100% GPU"  ✓ (column position extraction)
```

**Solution**:
```python
# Find column position from header
processor_start = header.find('PROCESSOR')
context_start = header.find('CONTEXT')

# Extract using fixed positions
processor = line[processor_start:context_start].strip()
# Returns: "100% GPU" ✓
```

### Compatibility
- ✓ NVIDIA GPUs (CUDA)
- ✓ AMD GPUs (ROCm)
- ✓ Apple Silicon (Metal)
- ✓ CPU-only systems
- ✓ Mixed GPU/CPU workloads

### Testing
All tests pass:
- ✓ Mock data parsing test
- ✓ Real `ollama ps` output parsing
- ✓ System GPU detection
- ✓ Module imports
- ✓ Backward compatibility

### Migration Notes
No migration needed. The fix is backward compatible:
- Existing scripts continue to work unchanged
- Reports will now correctly show GPU usage on NVIDIA systems
- No API changes

### Known Issues
None

### Future Improvements
- Consider adding `ollama info` parsing for more detailed GPU metrics
- Add support for other GPU types (Intel Arc, etc.)
- Implement streaming-based performance metrics for first token latency

---

## Previous Versions

### Version 1.0 (Initial Release)
- Created modular benchmark package
- Implemented GPU detection for macOS and Linux
- Added machine specification collection
- Created markdown report generation
