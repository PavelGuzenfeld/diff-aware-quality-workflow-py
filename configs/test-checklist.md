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
- [ ] **Sanitizer pass** — all tests pass under ASan + UBSan (`debug-asan` preset)
