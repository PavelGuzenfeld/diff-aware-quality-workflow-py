# Software Development Lifecycle

This document describes the full quality and security process enforced by this tooling, from developer workstation through merge.

## Pipeline Overview

```
 Developer Workstation          Pull Request               Post-Merge
 ─────────────────────         ──────────────────          ──────────────
 pre-commit hooks              diff-aware linting          CodeQL scheduled
   clang-format                  clang-tidy (Docker)       Infer scheduled
   clang-tidy                    cppcheck (Docker)         Fuzz corpus runs
   cppcheck                      clang-format
                                 ruff / flake8
 local scripts                   diff-cover
   diff-clang-tidy.sh
   diff-cppcheck.sh            banned pattern checks
   diff-clang-format.sh          cout/printf ban
   diff-file-naming.sh           raw new/delete ban
                                  gtest/gbenchmark ban
 CMake presets                    snake_case file naming
   debug-asan
   debug-tsan                  SAST scanners
   release-hardened              Semgrep (Python)
                                 CodeQL (C++ & Python)
 sanitizer builds                Infer (C++)
   ASan + UBSan                  pip-audit (Python)
   TSan
                               test coverage
                                 pytest + diff-cover

         git push ──────────> PR opened ──────────> merge
              │                    │                   │
              │                    │                   └─ post-merge scans
              │                    └─ quality gate (all checks must pass)
              └─ pre-commit hooks run locally
```

---

## Phase 1: Developer Workstation

Tools that run locally before code reaches CI.

### Pre-commit Hooks

Template: [`configs/.pre-commit-config.yaml`](../configs/.pre-commit-config.yaml)

| Hook | What it does |
|------|-------------|
| `clang-format` | Auto-formats C++ files on commit |
| `clang-tidy` | Static analysis with project `.clang-tidy` config |
| `cppcheck` | Bug and style checking |
| `trailing-whitespace` | Strips trailing whitespace |
| `end-of-file-fixer` | Ensures files end with newline |
| `check-yaml` | Validates YAML syntax |
| `check-added-large-files` | Blocks files > 500 KB |

Install: `pip install pre-commit && pre-commit install`

### Local Scripts

Run the same diff-aware checks that CI uses:

```bash
# clang-tidy on changed files
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"

# cppcheck on changed files
CPPCHECK_SUPPRESS=cppcheck.suppress ./scripts/diff-cppcheck.sh origin/main

# clang-format on changed files
./scripts/diff-clang-format.sh origin/main "cpp hpp h"

# file naming convention check
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt
```

### CMake Presets for Sanitizer Builds

Template: [`configs/CMakePresets-sanitizers.json`](../configs/CMakePresets-sanitizers.json)

| Preset | Description |
|--------|------------|
| `debug-asan` | AddressSanitizer + UndefinedBehaviorSanitizer |
| `release-asan` | ASan/UBSan at -O2 — catches UB the optimizer exploits |
| `debug-tsan` | ThreadSanitizer (mutually exclusive with ASan) |
| `release-hardened` | `FORTIFY_SOURCE=3`, `_GLIBCXX_ASSERTIONS`, stack protector, CFI |
| `debug` | Plain debug build |
| `release` | Plain optimized build |

```bash
cmake --preset debug-asan && cmake --build --preset debug-asan
ctest --test-dir build-asan --output-on-failure
```

### Compiler Warning Flags

Template: [`configs/cmake-warnings.cmake`](../configs/cmake-warnings.cmake)

Flags: `-Wall -Wextra -Wpedantic -Werror -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wconversion -Wsign-conversion -Wformat=2` plus GCC-specific extras (`-Wduplicated-cond`, `-Wlogical-op`).

```cmake
include(cmake-warnings.cmake)
target_link_libraries(my_target PRIVATE warnings)
```

---

## Phase 2: Pull Request Quality Gate

Automated checks that run on every PR. All must pass before merge.

### Diff-Aware Linting (C++)

Workflow: [`cpp-quality.yml`](../.github/workflows/cpp-quality.yml)

Only files changed in the PR are checked. Detection uses `git diff --name-only --diff-filter=ACMR` against the base branch. Pre-existing issues in untouched code never block PRs.

| Check | Tool | Runs in | Default |
|-------|------|---------|---------|
| Static analysis | clang-tidy | Docker | Always |
| Bug/style checking | cppcheck | Docker | Always |
| Code formatting | clang-format | Docker | Opt-in |
| CWE lexical scan | flawfinder | Host | Opt-in |

clang-tidy, cppcheck, and clang-format run inside the caller's Docker image, so they see the exact toolchain, headers, and `compile_commands.json` that the project uses. Flawfinder runs on the host (pure lexical scan, no compilation needed).

### Diff-Aware Linting (Python)

Workflow: [`python-quality.yml`](../.github/workflows/python-quality.yml)

| Check | Tool | Default |
|-------|------|---------|
| Lint (diff-aware) | ruff or flake8 via `diff-quality` | ruff |
| Tests | pytest with coverage | Always |
| Coverage (diff-aware) | diff-cover on changed lines | Always |

### Naming Conventions

| Check | What it enforces | Default |
|-------|-----------------|---------|
| File naming | `snake_case` for all file/directory names | Opt-in |
| Package naming | `include/<package_name>/` directories must be `snake_case` | Opt-in (via file naming) |
| Identifier naming | `snake_case` functions, `PascalCase` types (via clang-tidy) | Via config |

Built-in file naming exceptions: `CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, dotfiles, `__init__.py`, `requirements*.txt`.

### Banned Patterns

| Check | What it bans | Rationale | Default |
|-------|-------------|-----------|---------|
| cout/printf ban | `std::cout`, `std::cerr`, `printf`, `fprintf`, `puts` | Use structured logging | Opt-in |
| new/delete ban | Raw `new`/`delete` (excludes `make_unique`, `make_shared`, operator overloads) | Use smart pointers | Opt-in |
| doctest enforcement | `gtest` macros, `#include <gtest/...>`, Google Benchmark | Use doctest + nanobench | Opt-in |

### PR Comments

Each workflow posts a summary comment on the PR with a hidden HTML marker. On subsequent pushes, the same comment is updated instead of creating duplicates.

| Workflow | Marker |
|----------|--------|
| C++ quality | `<!-- cpp-quality-report -->` |
| Python quality | `<!-- python-quality-report -->` |
| Python SAST | `<!-- python-sast-report -->` |

### GitHub Annotations

Errors and warnings appear inline on the PR diff — reviewers see issues exactly where they occur, without reading CI logs.

---

## Phase 3: Security Scanning (SAST)

### Semgrep (Python)

Workflow: [`sast-python.yml`](../.github/workflows/sast-python.yml)

- Taint tracking for injection vulnerabilities
- OWASP Top 10 rule set
- SARIF results uploaded to GitHub Security tab
- Configurable rule sets

### CodeQL (C++ & Python)

Template: [`configs/ci-codeql.yml`](../configs/ci-codeql.yml)

- Inter-procedural taint tracking and data flow analysis
- 200+ CWEs for C++, 160+ for Python
- Detects: buffer overflows, use-after-free, SQL/command injection, format strings, XSS, SSRF
- Free for public repositories

### Infer (C++)

Template: [`configs/ci-infer.yml`](../configs/ci-infer.yml)

| Checker | What it finds |
|---------|--------------|
| Pulse | Use-after-free, null deref, memory leaks, taint flows, unnecessary copies |
| InferBO | Buffer overflow at multiple severity levels |
| RacerD | Data races, lock ordering, thread safety violations |

RacerD is unique among open-source SAST tools for thread safety analysis. Valuable for multi-threaded C++ (ROS2 executors, async callbacks).

### pip-audit (Python)

Workflow: [`sast-python.yml`](../.github/workflows/sast-python.yml)

- Checks `requirements.txt` against known CVE databases
- Uses `pypa/gh-action-pip-audit@v1.1.0`

---

## Phase 4: Testing & Hardening

### Edge Case Checklist

Template: [`configs/test-checklist.md`](../configs/test-checklist.md)

Every test suite must cover these 11 mandatory categories:

1. **Empty inputs** — empty containers, zero-length spans, null optionals
2. **Boundary conditions** — min/max values, off-by-one, size limits
3. **Single-element** — containers with exactly one item
4. **Invalid inputs** — out-of-range, wrong type, malformed data
5. **Resource exhaustion** — allocation failure, full buffers, timeout
6. **Concurrent access** — data races, lock ordering, atomic correctness
7. **Nanobench baselines** — performance-sensitive paths have benchmarks
8. **ASan + UBSan pass** — all tests pass under `debug-asan` preset
9. **TSan pass** — threaded code passes under `debug-tsan` preset
10. **Release + sanitizers** — tests pass under `release-asan` (optimizer exploits different UB)
11. **Fuzz harness** — parsing/input-handling code has a libFuzzer harness

### Sanitizer Builds

Run tests with AddressSanitizer, UndefinedBehaviorSanitizer, and ThreadSanitizer using the CMake presets.

### Multi-Compiler CI

Template: [`configs/ci-multi-compiler.yml`](../configs/ci-multi-compiler.yml)

- Matrix: GCC-13 + Clang-21
- ccache for fast rebuilds
- Multiple build modes (debug, release, sanitizers)

### Fuzzing

Template: [`configs/ci-fuzz.yml`](../configs/ci-fuzz.yml)

- libFuzzer with ASan + UBSan enabled
- Corpus caching between CI runs
- Crash artifact upload on failure
- Weekly scheduled + PR trigger

```cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    my_parser(data, size);
    return 0;
}
```

### Production Hardening

The `release-hardened` CMake preset enables:

| Flag | Purpose |
|------|---------|
| `_FORTIFY_SOURCE=3` | Runtime buffer overflow detection |
| `_GLIBCXX_ASSERTIONS` | Debug checks in libstdc++ containers |
| `-fstack-protector-strong` | Stack buffer overflow protection |
| `-fcf-protection=full` | Control Flow Integrity (Intel CET) |
| `-fPIE` / `-pie` | Position Independent Executable (ASLR) |

---

## Summary: What Runs When

| Phase | Trigger | Checks |
|-------|---------|--------|
| Pre-commit | `git commit` | clang-format, clang-tidy, cppcheck, whitespace, YAML |
| PR (C++) | Pull request | clang-tidy, cppcheck, clang-format, file naming, banned patterns |
| PR (Python) | Pull request | ruff/flake8, pytest, diff-cover |
| PR (SAST) | Pull request | Semgrep, pip-audit, CodeQL (optional) |
| Post-merge | Schedule/push | CodeQL, Infer, fuzz corpus runs |
| Local dev | Manual | Scripts, sanitizer presets, CMake warnings |
