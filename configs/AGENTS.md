# Agent Instructions — Quality Standard

> Copy this file to your repo root as `AGENTS.md`.
> It tells AI agents what your quality gates enforce so they write compliant code from the start.

## Quality Standard

This project uses [diff-aware quality workflows](https://github.com/PavelGuzenfeld/standard) for CI.
Only changed files are checked — but all new and modified code must pass.

### Always Enforced

- **clang-tidy** — clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability
- **cppcheck** — bug and style checking with project-specific suppressions

### Opt-in (enabled in this project)

> Remove items below that your project has not enabled.

- **clang-format** — C++23, 120-column, 4-space indent, Allman braces
- **File naming** — snake_case for all files and directories
- **Banned: cout/printf** — use structured logging instead
- **Banned: raw new/delete** — use smart pointers (`std::make_unique`, `std::make_shared`)
- **Banned: gtest/gbenchmark** — use doctest and nanobench
- **Identifier naming** — snake_case functions/variables, PascalCase types, trailing `_` for private members

### Python (if applicable)

- **Linting** — ruff (or flake8) on changed lines, zero violations required
- **Coverage** — pytest + diff-cover, minimum score on changed lines
- **SAST** — Semgrep (OWASP Top 10), pip-audit (CVE scanning)

## C++ Conventions

### File and Directory Naming

All files and directories must be `snake_case`. Pattern: lowercase letters, digits, underscores.

Valid: `flight_controller.cpp`, `nav_utils/`, `terrain_map.hpp`
Invalid: `FlightController.cpp`, `NavUtils/`, `terrainMap.hpp`

**Built-in exemptions** (no config needed):
`CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, `CHANGELOG.md`, `AGENTS.md`,
dotfiles (`.clang-tidy`, `.gitignore`), `__init__.py`, `requirements*.txt`

**Package directories**: `include/<package_name>/` must also be snake_case.

### Identifier Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Functions / methods | `snake_case` | `compute_heading()` |
| Variables / parameters | `snake_case` | `max_altitude` |
| Types / classes / structs | `PascalCase` | `FlightController` |
| Private members | `snake_case_` (trailing underscore) | `config_`, `state_` |
| Constants / enums | `UPPER_CASE` | `MAX_RETRIES` |
| Namespaces | `snake_case` | `nav_utils` |

### Include Convention

```cpp
#pragma once                          // not #ifndef guards
#include <system_headers>             // standard library first
#include "project/package_header.hpp" // project headers second
```

Minimize includes. Forward-declare where possible.

### Banned Patterns

| Pattern | Reason | Alternative |
|---------|--------|-------------|
| `std::cout`, `std::cerr`, `printf`, `fprintf`, `puts` | No structured logging | Use your project's logger (e.g., `RCLCPP_INFO`) |
| `new T`, `delete p` | Memory leaks | `std::make_unique<T>()`, `std::make_shared<T>()` |
| `#include <gtest/gtest.h>` | Non-standard for this project | `#include <doctest/doctest.h>` |
| `#include <benchmark/benchmark.h>` | Non-standard for this project | `#include <nanobench.h>` |

These bans apply to production code only. Test files (matching `test` in the path) may have different rules depending on project configuration.

## Testing Requirements

### Mandatory Test Categories

Every non-trivial module should cover these edge cases:

1. **Empty inputs** — empty containers, null optionals, zero-length spans
2. **Boundary conditions** — off-by-one, min/max values, INT_MAX, epsilon
3. **Single-element** — containers with one item
4. **Invalid inputs** — out-of-range, malformed strings, type mismatches
5. **Resource exhaustion** — allocation failure, full queues, disk full
6. **Concurrent access** — data races, deadlocks, torn reads (if applicable)
7. **Performance baselines** — nanobench for critical paths
8. **ASan + UBSan** — build and test with address/undefined sanitizers
9. **TSan** — build and test with thread sanitizer (if multi-threaded)
10. **Release + sanitizers** — verify optimized builds don't introduce UB
11. **Fuzz harness** — libFuzzer for parsers, serializers, and input handlers

### Sanitizer Build Presets

```bash
cmake --preset debug-asan    # ASan + UBSan
cmake --preset debug-tsan    # ThreadSanitizer
cmake --preset release-asan  # ASan + UBSan at -O2
```

## Code Formatting

### clang-format Settings

- Standard: C++23
- Column limit: 120
- Indent: 4 spaces
- Braces: Allman (opening brace on new line)
- No bin-packing of arguments

### clang-tidy Checks

Active check groups: `clang-analyzer-*`, `cppcoreguidelines-*`, `modernize-*`, `bugprone-*`, `performance-*`, `readability-*`

Run locally before pushing:

```bash
# Check only files changed vs main
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
./scripts/diff-file-naming.sh origin/main
```

## Python Conventions

- **Linter**: ruff (preferred) or flake8
- **Formatter**: ruff format or black
- **Test framework**: pytest
- **Coverage**: diff-cover (only changed lines must be covered)
- **SAST**: Semgrep for security, pip-audit for CVEs
- **Style**: PEP 8, type hints encouraged

## Local Verification

Run these before pushing to avoid CI failures:

```bash
# C++ (inside your Docker dev container)
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt

# Python
ruff check src/ tests/
pytest --cov=src tests/
```

## Customization

### Adding File Naming Exceptions

Create or edit `naming-exceptions.txt` (one regex per line):

```
# Vendor directories
vendor
third_party

# Generated code
.*_generated

# O3DE Gem directories
Gems
Code
```

Pass it to the workflow:

```yaml
with:
  file_naming_exceptions: naming-exceptions.txt
```

### Suppressing cppcheck Warnings

Add to `cppcheck.suppress`:

```
// Suppress specific check for a file
unusedFunction:src/legacy_module.cpp

// Suppress globally
shadowVariable
```

### Overriding clang-tidy Checks

Edit `.clang-tidy` in your repo root. The CI uses your config when present.

To disable a specific check:

```yaml
Checks: >-
  ...,
  -modernize-use-trailing-return-type
```

## CI Workflows

Every project integrating this standard must have a quality workflow in `.github/workflows/`.

### Required Workflows

- **C++**: `cpp-quality.yml` calling the reusable workflow
  - Required inputs: `docker_image`, `compile_commands_path`
  - Always enabled: clang-tidy, cppcheck
  - Opt-in: clang-format, file naming, banned patterns, identifier naming
- **Python**: `python-quality.yml` + `sast-python.yml`
  - Linting (ruff/flake8), pytest + diff-cover, Semgrep, pip-audit

### Optional Workflows

- `ci-codeql.yml` — GitHub CodeQL analysis
- `ci-infer.yml` — Facebook Infer static analysis (C++)
- `ci-fuzz.yml` — libFuzzer continuous fuzzing
- `ci-multi-compiler.yml` — GCC + Clang multi-compiler builds

### Verification

Confirm `.github/workflows/` contains the quality workflow for your language(s).

Full setup instructions: see `INTEGRATION.md`.

## SDLC Process

The standard supports a 4-phase Software Development Lifecycle:

- **Phase 1: Developer workstation** — pre-commit hooks, local diff-aware scripts, sanitizer CMake presets, editor integration
- **Phase 2: PR quality gate** — diff-aware linting, naming checks, banned pattern detection via CI workflows
- **Phase 3: SAST** — Semgrep (Python), CodeQL (C++/Python), Infer (C++), pip-audit (Python)
- **Phase 4: Hardening** — sanitizer builds in CI, fuzzing harnesses, multi-compiler testing

Full documentation: see `SDLC.md`.
