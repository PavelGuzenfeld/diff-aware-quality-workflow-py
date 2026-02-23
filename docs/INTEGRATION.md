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

## Automated Setup

Use the generator scripts to bootstrap quality tooling in your repo:

```bash
# 1. Generate .github/workflows/ YAML files
./scripts/generate-workflow.sh

# 2. Generate a tailored AGENTS.md for AI coding agents
./scripts/generate-agents-md.sh

# 3. Install git pre-commit hooks
./scripts/install-hooks.sh

# 4. Generate suppression/baseline files for incremental adoption
./scripts/generate-baseline.sh

# 5. Generate README badge markdown
./scripts/generate-badges.sh
```

These scripts are idempotent — safe to re-run as you enable more checks.

For manual step-by-step setup, continue below.

---

## Full C++ Setup

### 1. Docker Image Requirements

> **Important:** All C++ quality checks and tests must run inside your Docker dev container — both in CI and locally. Never install tools or dependencies on the host machine. The Docker image is the single source of truth; every CI check must be reproducible locally by running the same script inside the container.

The workflow runs tools inside your Docker image. It must have all dependencies needed for both CI and local development:

- **clang-tidy** (version 14+ recommended)
- **cppcheck** (version 2.10+ recommended)
- **clang-format** (if `enable_clang_format: true`)
- **cmake** and build toolchain (compilers, linker)
- **Project dependencies** (libraries, headers, ROS2 packages, etc.)
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

      # Step 8: Enable flawfinder CWE scan
      enable_flawfinder: true

      # Step 9: Upload SARIF to GitHub Security tab
      enable_sarif: true

    permissions:
      contents: read
      pull-requests: write
      security-events: write  # Required for SARIF upload
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

**Option A — Use the installer script** (recommended):

```bash
./scripts/install-hooks.sh
```

**Option B — Manual setup:**

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

### 8. Add Fuzz Testing

Copy the fuzz CI template:

```bash
cp configs/ci-fuzz.yml .github/workflows/fuzz.yml
```

Edit the `matrix.target` array with your fuzz target names:

```yaml
matrix:
  target: [parse_input, decode_frame]  # your fuzz targets
```

Create fuzz harnesses in `fuzz_targets/`:

```cpp
// fuzz_targets/parse_input.cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    my_parser(data, size);
    return 0;
}
```

In your `CMakeLists.txt`, gate fuzz targets with an option:

```cmake
option(ENABLE_FUZZING "Build fuzz targets" OFF)
if(ENABLE_FUZZING)
    add_executable(parse_input fuzz_targets/parse_input.cpp)
    target_link_libraries(parse_input PRIVATE my_library -fsanitize=fuzzer)
endif()
```

The template runs libFuzzer with ASan/UBSan, caches the corpus between runs, and uploads crash artifacts on failure. It triggers on PRs and weekly.

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

### Exclusion File

Create a `.standards-exclude` file listing paths to skip (vendored code, submodules, build artifacts):

```
# Vendored third-party
vendor/httplib.h

# External submodules (have own CI)
external_sdk/
protocol_icd/

# Build artifacts
build/
install/
```

One path prefix per line, `#` comments. All checks (clang-tidy, cppcheck, clang-format, banned patterns, file naming) respect this file:

```yaml
with:
  exclude_file: .standards-exclude
```

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

For simple ROS2 projects that already have `compile_commands.json` in the Docker image:

```yaml
with:
  docker_image: ghcr.io/your-org/ros2-dev:humble
  source_setup: 'source /opt/ros/humble/install/setup.bash'
  compile_commands_path: build/your_package
  cppcheck_include_file: cppcheck.include
  runner: self-hosted
```

For projects that need to build `compile_commands.json` as part of CI (e.g., colcon workspaces), use the pre-analysis script + build cache:

```yaml
with:
  docker_image: ghcr.io/your-org/ros2-dev:humble
  source_setup: 'source /opt/ros/humble/setup.bash'
  compile_commands_path: build
  pre_analysis_script: .github/scripts/pre-analysis.sh
  build_cache_key: clang-tidy-build-${{ hashFiles('**/CMakeLists.txt', '**/package.xml') }}
  runner: self-hosted
```

Example `.github/scripts/pre-analysis.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Build workspace to generate compile_commands.json
colcon build \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --event-handlers console_cohesion+

# Merge per-package compile databases into single file
python3 -c "
import json, glob
merged, seen = [], set()
for f in sorted(glob.glob('build/*/compile_commands.json')):
    for entry in json.load(open(f)):
        key = entry.get('file', '')
        if key not in seen:
            seen.add(key)
            merged.append(entry)
json.dump(merged, open('build/compile_commands.json', 'w'), indent=2)
print(f'Merged {len(merged)} entries')
"
```

The `build_cache_key` input enables `actions/cache@v4` to cache build artifacts between runs. On cache hit, only changed packages need rebuilding.

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

## Auto-Release Setup

The `auto-release.yml` reusable workflow auto-versions your project on every push to `main` using conventional commit prefixes. It creates an annotated git tag, a GitHub Release with auto-generated notes, and optionally a SLSA provenance attestation.

### 1. Add the workflow

Create `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  release:
    uses: PavelGuzenfeld/standard/.github/workflows/auto-release.yml@main
```

### 2. Use conventional commit prefixes

The workflow scans commits since the last `v*` tag and picks the highest bump:

| Prefix | Example | Bump |
|--------|---------|------|
| `feat!:` or `BREAKING CHANGE:` | `feat!: redesign API` | **major** |
| `feat:` or `feat(scope):` | `feat(auth): add OAuth` | **minor** |
| Everything else | `fix: null pointer`, `docs: update README` | **patch** (default) |

If no `v*` tag exists, the first release starts from `v0.0.1`.

### 3. Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `default_bump` | `patch` | Default bump when no conventional commit prefix is detected |
| `enable_provenance` | `false` | Enable SLSA provenance attestation for releases (opt-in) |

### How it works

1. Finds the latest semver tag (`git tag -l 'v*' --sort=-v:refname`)
2. Scans commit messages since that tag for conventional prefixes
3. Calculates the next version (major/minor/patch)
4. Creates an annotated git tag and pushes it
5. Creates a GitHub Release with auto-generated notes

No commits are made to `main` (avoids infinite loops). The version of record is the git tag.

---

## Security Hygiene Setup

These steps improve your OpenSSF Scorecard and supply chain security posture.

### 1. Add a Security Policy

Copy the template and fill in your contact details:

```bash
cp configs/SECURITY.md SECURITY.md
```

Edit the `TODO` placeholders with your security contact email and response timelines.

### 2. Enable Dependabot

Copy the template and uncomment ecosystems relevant to your project:

```bash
mkdir -p .github
cp configs/dependabot.yml .github/dependabot.yml
```

The template includes `github-actions` monitoring by default. Uncomment `pip`, `npm`, `cargo`, or `docker` sections as needed.

### 3. Enable Dangerous-Workflow Audit

Add to your infra-lint workflow call:

```yaml
with:
  enable_dangerous_workflows: true
```

This detects `pull_request_target` misuse and injection vectors (`${{ github.event.pull_request.title }}` in `run:` steps) in changed workflow files.

For local use, run the standalone script:

```bash
./scripts/check-dangerous-workflows.sh .github/workflows/
```

### 4. Enable Binary Artifact Detection

Add to your infra-lint workflow call:

```yaml
with:
  enable_binary_artifacts: true
```

This flags committed binary files (`.exe`, `.dll`, `.so`, `.jar`, `.pyc`, `.whl`, etc.) in PRs.

### 5. Enable SLSA Provenance

Add to your release workflow call:

```yaml
jobs:
  release:
    uses: PavelGuzenfeld/standard/.github/workflows/auto-release.yml@main
    with:
      enable_provenance: true
    permissions:
      contents: write
      id-token: write
      attestations: write
```

This creates a SLSA provenance attestation for each release using `actions/attest-build-provenance`.

---

## Workflow Inputs Reference

For the complete list of all inputs with defaults and descriptions, see the main [README](../README.md).

- [C++ inputs](../README.md#c-inputs) (52 inputs)
- [Python inputs](../README.md#python-inputs) (8 inputs)
- [Python SAST inputs](../README.md#python-sast-inputs) (8 inputs)
