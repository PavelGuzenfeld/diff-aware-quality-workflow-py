# Integration Guide

How to add these quality workflows to your project.

## Quick Start: C++

Add to `.github/workflows/quality.yml`:

```yaml
name: Quality
on:
  pull_request:
    branches: [main]

jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
    permissions:
      contents: read
      pull-requests: write
```

That's it. clang-tidy and cppcheck run on every PR, checking only changed files.

## Quick Start: Python

```yaml
name: Quality
on:
  pull_request:
    branches: [main]

jobs:
  python:
    uses: PavelGuzenfeld/standard/.github/workflows/python-quality.yml@main
    permissions:
      contents: read
      pull-requests: write

  sast:
    uses: PavelGuzenfeld/standard/.github/workflows/sast-python.yml@main
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

---

## Full C++ Setup

### 1. Docker Image Requirements

The workflow runs tools inside your Docker image. It must have:

- **clang-tidy** (version 14+ recommended)
- **cppcheck** (version 2.10+ recommended)
- **clang-format** (if `enable_clang_format: true`)
- **compile_commands.json** pre-generated at the path specified by `compile_commands_path`

The repo source gets volume-mounted into the container at `source_mount` (default: `/workspace/src`).

### 2. Copy Configs

Copy the configs you need from [`configs/`](../configs/) into your repo root:

```bash
# Required
cp configs/.clang-tidy .clang-tidy

# Recommended
cp configs/.clang-format .clang-format
cp configs/cppcheck.suppress cppcheck.suppress

# Optional
cp configs/.clang-tidy-naming .clang-tidy-naming
cp configs/naming-exceptions.txt naming-exceptions.txt
```

Customize as needed. The workflow uses your repo's configs when provided, otherwise falls back to the tool defaults.

### 3. Enable Checks One by One

Start with the defaults (clang-tidy + cppcheck) and enable more checks as your codebase is ready:

```yaml
jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-image:latest

      # Step 1: Add cppcheck include paths (fixes "file not found" warnings)
      cppcheck_include_file: cppcheck.include

      # Step 2: Add cppcheck suppressions
      cppcheck_suppress: cppcheck.suppress

      # Step 3: Enable formatting check
      enable_clang_format: true

      # Step 4: Enforce snake_case file naming
      enable_file_naming: true

      # Step 5: Ban cout/printf (use structured logging)
      ban_cout: true

      # Step 6: Ban raw new/delete (use smart pointers)
      ban_new: true

      # Step 7: Enforce doctest over gtest
      enforce_doctest: true

    permissions:
      contents: read
      pull-requests: write
```

### 4. Add SAST (C++)

#### CodeQL

Copy the template and add to your workflows:

```yaml
# .github/workflows/codeql.yml
name: CodeQL
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6 AM

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: cpp
          queries: security-extended
      - name: Build
        run: cmake -B build && cmake --build build
      - uses: github/codeql-action/analyze@v3
```

See [`configs/ci-codeql.yml`](../configs/ci-codeql.yml) for the full template with matrix over languages.

#### Infer

```yaml
# .github/workflows/infer.yml
name: Infer
on:
  push:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    container:
      image: fbinfer/infer:latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          infer capture -- cmake -B build
          infer analyze --pulse --bufferoverrun --racerd
```

See [`configs/ci-infer.yml`](../configs/ci-infer.yml) for the full template.

### 5. Add Agent Instructions

If your team uses AI coding agents (Claude Code, Copilot, Cursor, Codex, etc.), copy the agent instructions template:

```bash
cp configs/AGENTS.md AGENTS.md
```

Edit the "Opt-in" section to match which checks your project has enabled. This tells agents what conventions to follow so generated code passes CI on the first push.

### 6. Add Pre-commit Hooks

Copy the template and install:

```bash
cp configs/.pre-commit-config.yaml .pre-commit-config.yaml
pip install pre-commit
pre-commit install
```

### 7. Add CMake Presets & Warning Flags

```bash
cp configs/CMakePresets-sanitizers.json CMakePresets.json
cp configs/cmake-warnings.cmake cmake/cmake-warnings.cmake
```

In your `CMakeLists.txt`:

```cmake
include(cmake/cmake-warnings.cmake)
target_link_libraries(my_target PRIVATE warnings)
```

Build with sanitizers:

```bash
cmake --preset debug-asan && cmake --build --preset debug-asan
ctest --test-dir build-asan --output-on-failure
```

---

## Full Python Setup

### 1. Add Quality Workflow

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/standard/.github/workflows/python-quality.yml@main
    with:
      python_version: '3.12'
      python_linter: ruff          # or flake8 for ROS2/ament compat
      source_dirs: src
      test_dirs: tests
      fail_under: 80               # minimum diff-quality score
    permissions:
      contents: read
      pull-requests: write
```

### 2. Add SAST Workflow

```yaml
jobs:
  sast:
    uses: PavelGuzenfeld/standard/.github/workflows/sast-python.yml@main
    with:
      enable_semgrep: true
      semgrep_rules: 'p/python p/owasp-top-ten'
      enable_pip_audit: true
      enable_codeql: true           # free for public repos
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

### 3. Configure pyproject.toml for Ruff

```toml
[tool.ruff]
target-version = "py38"
line-length = 88

[tool.ruff.lint]
select = ["E", "W", "F", "I"]
```

---

## Customization

### Overriding Configs

All config inputs accept paths relative to the repo root:

```yaml
with:
  clang_tidy_config: .clang-tidy           # your custom config
  cppcheck_suppress: tools/cppcheck.suppress
  clang_format_config: .clang-format
  file_naming_exceptions: tools/naming-exceptions.txt
```

If a config input is empty, the tool uses its built-in defaults.

### cppcheck Include File

Create a `cppcheck.include` file with one include directory per line:

```
# ROS2 includes
/opt/ros/humble/include
/opt/ros/humble/include/rclcpp

# Project includes
src/my_package/include
```

Lines starting with `#` are comments. Blank lines are ignored.

### Custom File Naming Exceptions

Create a file with one regex per line, matched against path segments:

```
# Vendor directories (allow any casing)
vendor
third_party

# Generated code
.*_generated

# O3DE Gem directories
Gems
Code
```

### C++ Package Naming (`include/<package_name>/`)

C++ packages must follow the `include/<package_name>/` convention where `<package_name>` is snake_case.
The file naming check (`enable_file_naming: true`) enforces this automatically — all path segments are validated.

Valid: `include/nav_utils/`, `include/flight_controller/`
Invalid: `include/NavUtils/`, `include/flightController/`

### Custom Semgrep Rules

Pass additional rule sets:

```yaml
with:
  semgrep_rules: 'p/python p/owasp-top-ten p/django p/flask'
```

### ROS2 / Colcon Projects

For ROS2 projects that need environment sourcing:

```yaml
with:
  docker_image: ghcr.io/your-org/ros2-dev:humble
  source_setup: 'source /opt/ros/humble/install/setup.bash'
  compile_commands_path: build/your_package
  cppcheck_include_file: cppcheck.include
  runner: self-hosted
```

### Self-Hosted Runners

Set `runner: self-hosted` (or your label) on any workflow:

```yaml
with:
  runner: self-hosted
```

---

## Troubleshooting

### "No C++ files changed"

The workflow skips checks if no files with matching extensions changed in the PR. Default extensions: `cpp hpp h cc cxx`. Override with:

```yaml
with:
  file_extensions: 'cpp hpp h cc cxx c'
```

### clang-tidy: "compile_commands.json not found"

The `compile_commands_path` input must point to the directory containing `compile_commands.json` inside the Docker container (not the host). If your build output is at `/workspace/src/build/my_pkg/compile_commands.json`, set:

```yaml
with:
  compile_commands_path: build/my_pkg
```

### cppcheck: "file not found" for system headers

Provide include paths via `cppcheck_includes` or `cppcheck_include_file`:

```yaml
with:
  cppcheck_include_file: cppcheck.include
```

### Docker permission errors

The workflow mounts the repo at `source_mount` (default: `/workspace/src`). If your Docker image runs as a non-root user, ensure that user has read access to the mount point.

### PR comments not appearing

The workflow needs `pull-requests: write` permission:

```yaml
permissions:
  contents: read
  pull-requests: write
```

For SAST workflows that upload SARIF, also add:

```yaml
permissions:
  security-events: write
```

### diff-quality score too strict

Lower the threshold (default is 100, meaning zero violations allowed):

```yaml
with:
  fail_under: 80  # allow up to 20% violation rate on changed lines
```

### flake8 instead of ruff

For ROS2/ament compatibility:

```yaml
with:
  python_linter: flake8
```

---

## Workflow Inputs Reference

For the complete list of all inputs with defaults and descriptions, see the main [README](../README.md).

- [C++ inputs](../README.md#c-inputs) (20 inputs)
- [Python inputs](../README.md#python-inputs) (8 inputs)
- [Python SAST inputs](../README.md#python-sast-inputs) (8 inputs)
