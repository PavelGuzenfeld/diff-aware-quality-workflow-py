# Test Edge Case Checklist

Every test suite must cover these categories. Check off each item before submitting a PR.

## Mandatory Cases

- [ ] **Empty inputs** — empty containers, zero-length spans, null optionals
- [ ] **Boundary conditions** — min/max values, off-by-one, size limits
- [ ] **Single-element** — containers with exactly one item
- [ ] **Invalid inputs** — out-of-range, wrong type, malformed data
- [ ] **Resource exhaustion** — allocation failure, full buffers, timeout
- [ ] **Concurrent access** — data races, lock ordering, atomic correctness
- [ ] **Nanobench baselines** — performance-sensitive paths have benchmarks
- [ ] **Sanitizer pass (ASan + UBSan)** — all tests pass under `debug-asan` preset
- [ ] **Sanitizer pass (TSan)** — threaded code passes under `debug-tsan` preset
- [ ] **Release + sanitizers** — tests pass under `release-asan` (optimizer exploits different UB)
- [ ] **Fuzz harness** — parsing/input-handling code has a libFuzzer harness
