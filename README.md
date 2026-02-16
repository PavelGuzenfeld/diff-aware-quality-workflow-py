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

## ROCX Integration Example

For ROCX C++ projects running on self-hosted ARM64/x64 runners with Docker:

```yaml
name: Quality Checks
on:
  pull_request:
    branches: [master, dev_for_orin]

jobs:
  cpp:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/thebandofficial/rocx_dev:latest
      compile_commands_path: build/rocx_mission_control
      source_dirs: rocx/rocx_mission_control
      cppcheck_suppress: cppcheck.suppress
      cppcheck_include_file: cppcheck.include
      source_setup: 'source /opt/ros/humble/install/setup.bash'
      enable_clang_format: true
      enforce_doctest: true
      runner: self-hosted
    secrets: inherit
```

### cppcheck.include file format

Create a `cppcheck.include` file in your repo with one include directory per line:

```
# ROS2 includes
/opt/ros/humble/include
/opt/ros/humble/include/rclcpp

# Project includes
rocx/rocx_mission_control/include
rocx/rocx_common/include
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
8. Parse output into GitHub annotations (inline warnings/errors on the PR diff)
9. Post summary comment

### Python Pipeline

1. Install linter (`ruff` or `flake8` based on `python_linter` input)
2. Run `diff-quality --violations=<linter>` for diff-aware linting
3. Run pytest with coverage
4. Generate diff-cover report (coverage on changed lines only)
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
- `configs/CMakePresets-sanitizers.json` — CMake presets for ASan/UBSan, Debug, and Release builds
- `configs/ci-multi-compiler.yml` — GitHub Actions multi-compiler CI template (GCC-13 + Clang-21 x Debug/Release)
- `configs/test-checklist.md` — mandatory test edge case checklist

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
  CMakePresets-sanitizers.json  CMake presets (debug-asan, debug, release)
  ci-multi-compiler.yml Multi-compiler CI template (GCC-13 + Clang-21)
  test-checklist.md     Mandatory test edge case checklist
src/calculator.py       Python demo module
tests/test_calculator.py  Python demo tests
pyproject.toml          Ruff, pytest, coverage config
requirements.txt        Python dependencies
```

## Demo

This repo includes a Python calculator module (`src/calculator.py`) with tests to demonstrate the Python quality workflow. The `self-test.yml` workflow calls `python-quality.yml` on every push/PR to prove the template works.

The demo includes an intentional legacy lint issue (`unused_variable` in `subtract()`) that is suppressed via `per-file-ignores` in `pyproject.toml` — showing how diff-aware checking tolerates existing debt while enforcing standards on new code.

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
