# Diff-Aware Quality Workflows

Reusable GitHub Actions workflow templates for diff-aware code quality checks. Lint and analyze only the files changed in a PR — no noise from legacy code.

Supports **C++** (clang-tidy, cppcheck) and **Python** (ruff/flake8, diff-cover, pytest).

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
| `cppcheck_std` | `c++23` | C++ standard for cppcheck |
| `runner` | `ubuntu-latest` | Runner label |
| `file_extensions` | `cpp hpp h cc cxx` | File extensions to check |

### Python Quality (reusable workflow)

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/python-quality.yml@main
    with:
      python_version: '3.10'
      python_linter: ruff
    permissions:
      contents: read
      pull-requests: write
```

#### Python Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.10` | Python version to use |
| `target_python` | `py38` | Target Python version for ruff |
| `python_linter` | `ruff` | Linter backend: `ruff` (fast, modern) or `flake8` (ROS2/ament compat) |
| `source_dirs` | `src` | Source directories |
| `test_dirs` | `tests` | Test directories |
| `ruff_select` | `E,W,F,I` | Ruff rule selection |
| `fail_under` | `100` | Minimum diff-quality score (0-100) |
| `runner` | `ubuntu-latest` | Runner label |

## Full-Featured Example

For C++ projects running on self-hosted ARM64/x64 runners with Docker:

```yaml
name: Quality Checks
on:
  pull_request:
    branches: [master, dev_for_orin]

jobs:
  cpp:
    uses: PavelGuzenfeld/diff-aware-quality-workflow-py/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
      compile_commands_path: build/your_package
      source_dirs: src/my_package
      cppcheck_suppress: cppcheck.suppress
      cppcheck_includes: '/opt/ros/humble/include src/my_package/include'
      runner: self-hosted
    secrets: inherit
```

## How It Works

### Diff-Aware Checking

All workflows detect changed files using `git diff --name-only --diff-filter=ACMR` against the PR base branch. Only those files are linted/analyzed, so pre-existing issues in untouched code never block PRs.

### PR Comment Updates

Each workflow posts a summary comment on the PR with a hidden marker (`<!-- quality-report -->`). On subsequent pushes, the same comment is updated instead of creating duplicates.

### C++ Pipeline

1. Detect changed C++ files
2. Run clang-tidy on each file inside the caller's Docker image
3. Run cppcheck on changed files inside Docker
4. Parse output into GitHub annotations (inline warnings/errors on the PR diff)
5. Post summary comment

### Python Pipeline

1. Install linter (`ruff` or `flake8` based on `python_linter` input)
2. Run `diff-quality --violations=<linter>` for diff-aware linting
3. Run pytest with coverage
4. Generate diff-cover report (coverage on changed lines only)
5. Post summary comment

## Default Configs

The `configs/` directory contains default configs suitable for most C++ projects:

- `configs/.clang-tidy` — clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability checks with sensible exclusions
- `configs/cppcheck.suppress` — generic suppressions (unusedFunction, shadowVariable, etc.)

Copy these into your repo and customize as needed.

## Scripts

Standalone scripts for running outside GitHub Actions:

```bash
# clang-tidy on changed files
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"

# cppcheck on changed files
CPPCHECK_SUPPRESS=cppcheck.suppress \
CPPCHECK_INCLUDES="/opt/ros/humble/include" \
./scripts/diff-cppcheck.sh origin/main
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
configs/
  .clang-tidy           Default clang-tidy config
  cppcheck.suppress     Default cppcheck suppressions
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
