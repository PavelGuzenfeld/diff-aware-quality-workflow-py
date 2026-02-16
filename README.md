# Diff-Aware Quality Workflows

Reusable GitHub Actions workflow templates for diff-aware code quality checks. Lint and analyze only the files changed in a PR — no noise from legacy code.

Supports **C++** (clang-tidy, cppcheck, clang-format) and **Python** (ruff/flake8, diff-cover, pytest).

## Usage

### C++ Quality (reusable workflow)

Call from your repository's workflow:

```yaml
# .github/workflows/quality.yml
name: Quality Checks
on:
  pull_request:
    branches: [main]

jobs:
  cpp:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
      compile_commands_path: build
      runner: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
```

#### C++ Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image with clang-tidy, cppcheck, and compile_commands.json |
| `compile_commands_path` | `build` | Path to compile_commands.json inside the container |
| `source_mount` | `/workspace/src` | Where repo source is mounted inside the container |
| `clang_tidy_config` | `''` | Path to .clang-tidy config (empty = use repo default) |
| `cppcheck_suppress` | `''` | Path to cppcheck suppressions file |
| `cppcheck_includes` | `''` | Space-separated include directories |
| `cppcheck_include_file` | `''` | Path to file containing include dirs (one per line, supports `#` comments) |
| `cppcheck_std` | `c++23` | C++ standard for cppcheck |
| `enable_clang_format` | `false` | Enable clang-format check on changed files (opt-in) |
| `clang_format_config` | `''` | Path to .clang-format config (empty = use repo default) |
| `source_setup` | `''` | Shell command to source before tools (e.g., `source /opt/ros/humble/install/setup.bash`) |
| `runner` | `ubuntu-latest` | Runner label |
| `file_extensions` | `cpp hpp h cc cxx` | File extensions to check |
| `enforce_doctest` | `false` | Require doctest instead of gtest in test files |
| `test_file_pattern` | `test` | Grep pattern to identify test files (matched against path) |
| `enable_file_naming` | `false` | Enable file/directory naming convention check (snake_case, opt-in) |
| `file_naming_exceptions` | `''` | Path to file with additional naming exception regexes (one per line) |
| `file_naming_allowed_prefixes` | `_` | Space-separated allowed prefixes for file/dir names |
| `ban_cout` | `false` | Ban `std::cout`/`cerr`/`clog` and `printf` family in non-test source files (opt-in) |
| `ban_new` | `false` | Ban raw `new`/`delete` in non-test source files (opt-in) |

### Python Quality (reusable workflow)

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/python-quality.yml@main
    with:
      python_version: '3.12'
      python_linter: ruff
    permissions:
      contents: read
      pull-requests: write
```

#### Python Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `target_python` | `py38` | Target Python version for ruff |
| `python_linter` | `ruff` | Linter backend: `ruff` (fast, modern) or `flake8` (ROS2/ament compat) |
| `source_dirs` | `src` | Source directories |
| `test_dirs` | `tests` | Test directories |
| `ruff_select` | `E,W,F,I` | Ruff rule selection |
| `fail_under` | `100` | Minimum diff-quality score (0-100) |
| `runner` | `ubuntu-latest` | Runner label |

### Python SAST (reusable workflow)

Security scanning for Python projects — Semgrep taint analysis, pip-audit dependency CVE scanning, and optional CodeQL deep analysis.

```yaml
jobs:
  sast:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/sast-python.yml@main
    with:
      enable_semgrep: true
      semgrep_rules: 'p/python p/owasp-top-ten'
      enable_pip_audit: true
      enable_codeql: true  # free for public repos
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

#### Python SAST Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `enable_semgrep` | `true` | Enable Semgrep security scanning |
| `semgrep_rules` | `p/python p/owasp-top-ten` | Semgrep rule sets (space-separated) |
| `enable_pip_audit` | `true` | Enable pip-audit dependency CVE scanning |
| `requirements_file` | `requirements.txt` | Path to requirements file for pip-audit |
| `enable_codeql` | `false` | Enable CodeQL deep analysis (free for public repos) |
| `codeql_queries` | `security-extended` | CodeQL query suite |
| `runner` | `ubuntu-latest` | Runner label |

## Full-Featured Example

For C++ projects running on self-hosted runners with Docker (e.g., ROS2 + colcon):

```yaml
name: Quality Checks
on:
  pull_request:
    branches: [main, master]

jobs:
  cpp:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
      compile_commands_path: build/your_package
      cppcheck_suppress: cppcheck.suppress
      cppcheck_include_file: cppcheck.include
      source_setup: 'source /opt/ros/humble/install/setup.bash'
      enable_clang_format: true
      enforce_doctest: true
      ban_cout: true
      ban_new: true
      enable_file_naming: true
      runner: self-hosted
    permissions:
      contents: read
      pull-requests: write
```

### cppcheck.include file format

Create a `cppcheck.include` file in your repo with one include directory per line:

```
# ROS2 includes
/opt/ros/humble/include
/opt/ros/humble/include/rclcpp

# Project includes
src/my_package/include
src/my_common/include
```

Lines starting with `#` are treated as comments and blank lines are ignored.

## How It Works

### Diff-Aware Checking

All workflows detect changed files using `git diff --name-only --diff-filter=ACMR` against the PR base branch. Only those files are linted/analyzed, so pre-existing issues in untouched code never block PRs.

### PR Comment Updates

Each workflow posts a summary comment on the PR with a hidden marker (`<!-- quality-report -->`). On subsequent pushes, the same comment is updated instead of creating duplicates.

### C++ Pipeline

1. Detect changed C++ files
2. Run clang-tidy on each file inside the caller's Docker image
3. Run cppcheck on changed files inside Docker
4. Run clang-format on changed files (if enabled)
5. Check for gtest/Google Benchmark usage in test files (if doctest enforcement enabled)
6. Check file/directory naming conventions (if file naming enabled)
7. Check for banned `std::cout`/`printf` in non-test files (if `ban_cout` enabled)
8. Check for raw `new`/`delete` in non-test files (if `ban_new` enabled)
9. Parse output into GitHub annotations (inline warnings/errors on the PR diff)
10. Post summary comment

### Python Pipeline

1. Install linter (`ruff` or `flake8` based on `python_linter` input)
2. Run `diff-quality --violations=<linter>` for diff-aware linting
3. Run pytest with coverage
4. Generate diff-cover report (coverage on changed lines only)
5. Post summary comment

### Python SAST Pipeline

1. Run Semgrep with configurable rule sets (taint tracking, OWASP Top 10)
2. Run pip-audit for dependency CVE scanning
3. Run CodeQL deep analysis (optional, free for public repos)
4. Upload SARIF results to GitHub Security tab
5. Post summary comment

## Default Configs

The `configs/` directory contains default configs suitable for most C++ projects:

- `configs/.clang-tidy` — clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability checks with sensible exclusions
- `configs/.clang-format` — C++23 config: 120-col line limit, 4-space indent, Allman-style braces, right-aligned pointers
- `configs/cppcheck.suppress` — generic suppressions (unusedFunction, shadowVariable, etc.) with commented vendor examples
- `configs/.clang-tidy-naming` — `readability-identifier-naming` CheckOptions (snake_case functions, PascalCase types, trailing `_` for private members)
- `configs/naming-exceptions.txt` — template for file naming exception patterns (one regex per line)
- `configs/repo-structure-ros2.txt` — sample ROS2 package structure config for `check-repo-structure.sh`
- `configs/.pre-commit-config.yaml` — pre-commit template with clang-format, clang-tidy, cppcheck hooks
- `configs/CMakePresets-sanitizers.json` — CMake presets: `debug-asan`, `release-asan`, `debug-tsan`, `release-hardened`, `debug`, `release`
- `configs/ci-multi-compiler.yml` — GitHub Actions multi-compiler CI template (GCC-13 + Clang-21) with ccache
- `configs/ci-fuzz.yml` — libFuzzer CI template with corpus caching and crash artifact upload
- `configs/cmake-warnings.cmake` — CMake module with recommended GCC/Clang warning flags (`-Wall -Wextra -Wpedantic -Werror` + extras)
- `configs/test-checklist.md` — mandatory test edge case checklist (ASan, TSan, fuzzing)
- `configs/ci-codeql.yml` — CodeQL SAST template for C++ and Python (inter-procedural taint tracking, 200+ CWEs)
- `configs/ci-infer.yml` — Facebook Infer template (Pulse memory safety, InferBO buffer overflow, RacerD thread safety)

Copy these into your repo and customize as needed.

### Identifier Naming with clang-tidy

The `configs/.clang-tidy-naming` file provides `readability-identifier-naming` CheckOptions that enforce:

| Identifier | Convention | Example |
|-----------|-----------|---------|
| Functions/methods | `snake_case` | `process_data()` |
| Variables/parameters | `snake_case` | `frame_count` |
| Classes/structs/enums | `PascalCase` | `DataProcessor` |
| Private/protected members | `snake_case_` (trailing `_`) | `buffer_` |
| Public members | `snake_case` | `frame_id` |
| Namespaces | `snake_case` | `nav_utils` |
| Constants/constexpr | `UPPER_CASE` | `MAX_RETRIES` |
| Enum constants | `PascalCase` | `ReadyState` |
| Macros | `UPPER_CASE` | `LOG_DEBUG` |
| Template parameters | `PascalCase` | `ValueType` |

To use, add `readability-identifier-naming` to your `.clang-tidy` Checks and merge the CheckOptions from this file.

### File Naming Convention

When `enable_file_naming` is enabled, the workflow checks that all changed file and directory names follow `snake_case` convention (`^[a-z][a-z0-9_]*$`).

**Built-in exceptions** (always exempt):
- Well-known files: `CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, `Makefile`, `package.xml`, `pyproject.toml`, `Cargo.toml`, etc.
- Dotfiles/dotdirs: `.gitignore`, `.github/`, `.clang-tidy`, etc.
- Python special files: `__init__.py`, `__main__.py`, `__pycache__/`, `py.typed`
- Requirements files: `requirements*.txt`

**Allowed prefixes** (`file_naming_allowed_prefixes`): For mixed C++/Python projects, leading prefixes like `_` are allowed. For example, with prefix `_`, the name `_bindings.so` is valid because `bindings` passes the snake_case check.

**Custom exceptions** (`file_naming_exceptions`): Point to a file with one regex per line. Lines starting with `#` and blank lines are ignored. Each regex is matched against path segments (directory names or filenames).

### CMake Presets

The `configs/CMakePresets-sanitizers.json` provides presets for different build configurations. Copy to your project root as `CMakePresets.json`.

| Preset | Type | Description |
|--------|------|-------------|
| `debug-asan` | Debug | AddressSanitizer + UndefinedBehaviorSanitizer |
| `release-asan` | Release | ASan/UBSan at optimization level — catches UB the optimizer exploits |
| `debug-tsan` | Debug | ThreadSanitizer (mutually exclusive with ASan) |
| `release-hardened` | Release | Production hardening: `_FORTIFY_SOURCE=3`, `_GLIBCXX_ASSERTIONS`, stack protector, CFI |
| `debug` | Debug | Plain debug build |
| `release` | Release | Plain optimised build |

```bash
cmake --preset debug-asan && cmake --build --preset debug-asan
ctest --test-dir build-asan --output-on-failure
```

### Compiler Warning Flags

The `configs/cmake-warnings.cmake` module creates an `INTERFACE` library target with recommended warning flags:

```cmake
include(configs/cmake-warnings.cmake)
target_link_libraries(my_target PRIVATE warnings)
```

Flags: `-Wall -Wextra -Wpedantic -Werror -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wconversion -Wsign-conversion -Wformat=2` plus GCC-specific extras (`-Wduplicated-cond`, `-Wlogical-op`, etc.).

### Fuzzing CI Template

The `configs/ci-fuzz.yml` provides a GitHub Actions template for libFuzzer-based fuzz testing:

- Matrix over fuzz targets
- ASan + UBSan enabled during fuzzing
- Corpus caching between runs
- Crash artifact upload on failure
- Weekly scheduled runs + PR triggers

Requires fuzz harnesses with the standard libFuzzer entry point:

```cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    my_parser(data, size);
    return 0;
}
```

### CodeQL SAST Template

The `configs/ci-codeql.yml` provides deep inter-procedural taint tracking and data flow analysis:

- Supports both C++ and Python (matrix over languages)
- `security-extended` query suite: 200+ CWEs for C++, 160+ CWEs for Python
- Detects: buffer overflows, use-after-free, SQL/command injection, format strings, XSS, SSRF
- Results appear in GitHub Security tab and as PR annotations
- Free for public repositories (private repos require GitHub Advanced Security license)

### Infer SAST Template

The `configs/ci-infer.yml` provides Facebook/Meta's static analyzer with three checkers:

| Checker | What it finds |
|---------|---------------|
| `pulse` | Use-after-free, null deref, memory leaks, taint flows, unnecessary copies |
| `bufferoverrun` | Buffer overflow at multiple severity levels |
| `racerd` | Data races, lock ordering, thread safety violations |

RacerD is unique among open-source SAST tools — no other free tool provides comparable thread safety analysis. Particularly valuable for multi-threaded C++ (ROS2 executors, async callbacks).

## Scripts

Standalone scripts for running outside GitHub Actions:

```bash
# clang-tidy on changed files
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"

# cppcheck on changed files
CPPCHECK_SUPPRESS=cppcheck.suppress \
CPPCHECK_INCLUDES="/opt/ros/humble/include" \
./scripts/diff-cppcheck.sh origin/main

# clang-format on changed files
CLANG_FORMAT_CONFIG=.clang-format \
./scripts/diff-clang-format.sh origin/main "cpp hpp h"

# file naming convention check
NAMING_ALLOWED_PREFIXES="_" \
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt

# repo structure validation
./scripts/check-repo-structure.sh configs/repo-structure-ros2.txt /path/to/package
```

## Project Structure

```
.github/workflows/
  cpp-quality.yml       Reusable C++ quality workflow
  python-quality.yml    Reusable Python quality workflow
  sast-python.yml       Reusable Python SAST workflow (Semgrep, pip-audit, CodeQL)
  self-test.yml         Self-test (calls python-quality on demo code)
  gatekeeper-checks.yml Push checks for this repo
  pull-request-feedback.yml  PR feedback for this repo
scripts/
  diff-clang-tidy.sh    Standalone clang-tidy diff script
  diff-cppcheck.sh      Standalone cppcheck diff script
  diff-clang-format.sh  Standalone clang-format diff script
  diff-file-naming.sh   Standalone file naming convention check
  check-repo-structure.sh  Standalone repo structure validation
configs/
  .clang-tidy           Default clang-tidy config
  .clang-format         Default clang-format config (C++23, Allman braces, 120-col)
  .clang-tidy-naming    Identifier naming CheckOptions for readability-identifier-naming
  cppcheck.suppress     Default cppcheck suppressions
  naming-exceptions.txt Template for file naming exception patterns
  repo-structure-ros2.txt  Sample ROS2 package structure config
  .pre-commit-config.yaml  Pre-commit hooks template (clang-format, clang-tidy, cppcheck)
  CMakePresets-sanitizers.json  CMake presets (debug-asan, release-asan, debug-tsan, release-hardened, debug, release)
  ci-multi-compiler.yml Multi-compiler CI template (GCC-13 + Clang-21) with ccache
  ci-fuzz.yml           libFuzzer CI template with corpus caching
  ci-codeql.yml         CodeQL SAST template (C++ & Python, 200+ CWEs)
  ci-infer.yml          Facebook Infer template (Pulse, InferBO, RacerD)
  cmake-warnings.cmake  CMake warning flags module (GCC/Clang)
  test-checklist.md     Mandatory test edge case checklist
tests/
  test_calculator.py    Python demo tests
  test_patterns.sh      Pattern and script validation tests (109 tests)
src/calculator.py       Python demo module
pyproject.toml          Ruff, pytest, coverage config
requirements.txt        Python dependencies
```

## Demo

This repo includes a Python calculator module (`src/calculator.py`) with tests to demonstrate the Python quality workflow. The `self-test.yml` workflow calls `python-quality.yml` on every push/PR to prove the template works.

The demo code passes all linting checks (ruff) and is used by the `gatekeeper-checks.yml` workflow to verify the repo stays clean on every push.

### Run locally

```bash
pip install -r requirements.txt

# Lint
ruff check src/ tests/

# Test
pytest --cov

# Diff-aware lint (compare against main)
diff-quality --violations=ruff.check --compare-branch=origin/main
```

## License

MIT License - see [LICENSE](LICENSE).
