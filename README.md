# Standard

Reusable GitHub Actions for C++ and Python quality gates. Diff-aware linting, SAST, sanitizers, fuzzing — only check what changed.

## What It Does

- **Diff-aware** — only files changed in the PR are checked; legacy code never blocks merges
- **C++ quality** — clang-tidy, cppcheck, clang-format inside your Docker image
- **Python quality** — ruff/flake8 + pytest + diff-cover on changed lines
- **Security scanning** — Semgrep, CodeQL, Infer, pip-audit
- **Banned patterns** — cout/printf, raw new/delete, gtest (all opt-in)
- **Naming enforcement** — snake_case files and `include/<package_name>/` directories, identifier naming via clang-tidy
- **Hardening templates** — sanitizer presets, multi-compiler CI, fuzzing, production flags
- **PR feedback** — inline annotations + auto-updating summary comments

## Quick Start

### C++

```yaml
# .github/workflows/quality.yml
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

### Python

```yaml
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

## Documentation

| Document | Description |
|----------|------------|
| **[SDLC Process](docs/SDLC.md)** | Full lifecycle: pre-commit, PR gates, SAST, testing, hardening |
| **[Integration Guide](docs/INTEGRATION.md)** | Step-by-step setup for C++ and Python projects |
| **[Roadmap](docs/ROADMAP.md)** | Planned features: auto Jira tickets from scans, trend dashboard |

## Reusable Workflows

| Workflow | Language | What it checks |
|----------|----------|---------------|
| [`cpp-quality.yml`](.github/workflows/cpp-quality.yml) | C++ | clang-tidy, cppcheck, clang-format, flawfinder, file naming, banned patterns |
| [`python-quality.yml`](.github/workflows/python-quality.yml) | Python | ruff/flake8 (diff-aware), pytest, diff-cover |
| [`sast-python.yml`](.github/workflows/sast-python.yml) | Python | Semgrep, pip-audit, CodeQL |

## Workflow Inputs

<details>
<summary><strong>C++ Inputs</strong> (25 inputs)</summary>

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image with clang-tidy, cppcheck, and compile_commands.json |
| `compile_commands_path` | `build` | Path to compile_commands.json inside the container |
| `source_mount` | `/workspace/src` | Where repo source is mounted inside the container |
| `clang_tidy_config` | `''` | Path to .clang-tidy config (empty = use repo default) |
| `cppcheck_suppress` | `''` | Path to cppcheck suppressions file |
| `cppcheck_includes` | `''` | Space-separated include directories |
| `cppcheck_include_file` | `''` | Path to file containing include dirs (one per line, `#` comments) |
| `cppcheck_std` | `c++23` | C++ standard for cppcheck |
| `enable_clang_format` | `false` | Enable clang-format check |
| `clang_format_config` | `''` | Path to .clang-format config |
| `source_setup` | `''` | Shell command to source before tools (e.g., ROS2 setup.bash) |
| `runner` | `ubuntu-latest` | Runner label |
| `file_extensions` | `cpp hpp h cc cxx` | File extensions to check |
| `enforce_doctest` | `false` | Require doctest instead of gtest |
| `test_file_pattern` | `test` | Grep pattern to identify test files |
| `enable_file_naming` | `false` | Enable snake_case file naming check |
| `file_naming_exceptions` | `''` | Path to naming exception regexes |
| `file_naming_allowed_prefixes` | `_` | Allowed prefixes for file names |
| `ban_cout` | `false` | Ban cout/cerr/printf in non-test files |
| `ban_new` | `false` | Ban raw new/delete in non-test files |
| `clang_tidy_jobs` | `4` | Parallel clang-tidy jobs inside Docker |
| `exclude_file` | `''` | Path to file listing excluded paths (one per line, `#` comments) |
| `enable_flawfinder` | `false` | Enable flawfinder CWE lexical scan |
| `flawfinder_min_level` | `2` | Minimum flawfinder finding level (1-5) |
| `enable_sarif` | `false` | Upload SARIF to GitHub Security tab |

</details>

<details>
<summary><strong>Python Inputs</strong> (8 inputs)</summary>

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `target_python` | `py38` | Target Python version for ruff |
| `python_linter` | `ruff` | Linter: `ruff` or `flake8` |
| `source_dirs` | `src` | Source directories |
| `test_dirs` | `tests` | Test directories |
| `ruff_select` | `E,W,F,I` | Ruff rule selection |
| `fail_under` | `100` | Minimum diff-quality score (0-100) |
| `runner` | `ubuntu-latest` | Runner label |

</details>

<details>
<summary><strong>Python SAST Inputs</strong> (8 inputs)</summary>

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `enable_semgrep` | `true` | Enable Semgrep security scanning |
| `semgrep_rules` | `p/python p/owasp-top-ten` | Semgrep rule sets |
| `enable_pip_audit` | `true` | Enable pip-audit CVE scanning |
| `requirements_file` | `requirements.txt` | Path to requirements file |
| `enable_codeql` | `false` | Enable CodeQL (free for public repos) |
| `codeql_queries` | `security-extended` | CodeQL query suite |
| `runner` | `ubuntu-latest` | Runner label |

</details>

## Full-Featured C++ Example

```yaml
jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
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

## Configs

| Config | Purpose |
|--------|---------|
| [`.clang-tidy`](configs/.clang-tidy) | clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability |
| [`.clang-format`](configs/.clang-format) | C++23, 120-col, 4-space indent, Allman braces |
| [`.clang-tidy-naming`](configs/.clang-tidy-naming) | Identifier naming: snake_case functions, PascalCase types, trailing `_` private |
| [`cppcheck.suppress`](configs/cppcheck.suppress) | Generic suppressions with commented vendor examples |
| [`naming-exceptions.txt`](configs/naming-exceptions.txt) | File naming exception template (one regex per line) |
| [`.pre-commit-config.yaml`](configs/.pre-commit-config.yaml) | Pre-commit hooks: clang-format, clang-tidy, cppcheck |
| [`CMakePresets-sanitizers.json`](configs/CMakePresets-sanitizers.json) | CMake presets: ASan, TSan, release-hardened |
| [`ci-multi-compiler.yml`](configs/ci-multi-compiler.yml) | Multi-compiler CI: GCC-13 + Clang-21, ccache |
| [`ci-fuzz.yml`](configs/ci-fuzz.yml) | libFuzzer CI with corpus caching |
| [`ci-codeql.yml`](configs/ci-codeql.yml) | CodeQL SAST: 200+ CWEs for C++, 160+ for Python |
| [`ci-infer.yml`](configs/ci-infer.yml) | Infer: Pulse, InferBO, RacerD thread safety |
| [`cmake-warnings.cmake`](configs/cmake-warnings.cmake) | Warning flags: -Wall -Wextra -Wpedantic -Werror + extras |
| [`test-checklist.md`](configs/test-checklist.md) | Mandatory test edge case checklist (11 categories) |
| [`repo-structure-ros2.txt`](configs/repo-structure-ros2.txt) | ROS2 package structure validation template |
| [`AGENTS.md`](configs/AGENTS.md) | AI agent instructions template for consuming projects |

## Scripts

Standalone scripts for local development (same logic as CI):

```bash
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt
./scripts/check-repo-structure.sh configs/repo-structure-ros2.txt .
```

## Project Structure

```
.github/workflows/
  cpp-quality.yml           Reusable C++ quality workflow (clang-tidy, cppcheck, + 5 opt-in checks)
  python-quality.yml        Reusable Python quality workflow (ruff/flake8, pytest, diff-cover)
  sast-python.yml           Reusable Python SAST workflow (Semgrep, pip-audit, CodeQL)
  self-test.yml             Dogfood: runs python-quality on this repo's demo code
  gatekeeper-checks.yml     Push checks for this repo
  pull-request-feedback.yml PR feedback for this repo
scripts/                    Standalone diff-aware scripts for local use
configs/                    Drop-in configs, CI templates, and agent instructions (15 files)
tests/
  test_patterns.sh          Pattern validation tests (109 tests)
  test_calculator.py        Python demo tests
docs/
  SDLC.md                   Full software development lifecycle document
  INTEGRATION.md            Step-by-step integration guide
AGENTS.md                   AI agent instructions for contributing to this repo
src/calculator.py           Python demo module
```

## How It Works

All workflows detect changed files using `git diff --name-only --diff-filter=ACMR` against the PR base branch. Only those files are linted/analyzed, so pre-existing issues in untouched code never block PRs.

Each workflow posts a summary comment on the PR with a hidden HTML marker. On subsequent pushes, the same comment is updated instead of creating duplicates.

C++ tools run inside the caller's Docker image, so they see the exact toolchain, headers, and `compile_commands.json` the project uses.

## License

MIT License - see [LICENSE](LICENSE).
