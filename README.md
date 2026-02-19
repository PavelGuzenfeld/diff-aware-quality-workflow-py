# Standard

Reusable GitHub Actions for C++ and Python quality gates. Diff-aware linting, SAST, sanitizers, fuzzing — only check what changed.

## What It Does

- **Diff-aware** — only files changed in the PR are checked; legacy code never blocks merges
- **C++ quality** — clang-tidy, cppcheck, clang-format, flawfinder, ShellCheck, Hadolint inside your Docker image
- **Runtime analysis** — ASan/UBSan, TSan, gcov/lcov coverage, IWYU (all opt-in)
- **Python quality** — ruff/flake8 + pytest + diff-cover on changed lines
- **Security scanning** — Semgrep, CodeQL, Infer, pip-audit
- **SBOM & supply chain** — Syft container scan, source dependency scan, Grype vulnerability scanning
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
| **[Versioning Rules](docs/VERSIONING.md)** | SemVer policy: initial versions, bump rules, git tags |
| **[Roadmap](docs/ROADMAP.md)** | Conventions, coding standards, and planned features |

## Reusable Workflows

| Workflow | Language | What it checks |
|----------|----------|---------------|
| [`cpp-quality.yml`](.github/workflows/cpp-quality.yml) | C++ | clang-tidy, cppcheck, clang-format, flawfinder, ShellCheck, Hadolint, sanitizers, TSAN, coverage, IWYU, file naming, banned patterns |
| [`python-quality.yml`](.github/workflows/python-quality.yml) | Python | ruff/flake8 (diff-aware), pytest, diff-cover |
| [`sast-python.yml`](.github/workflows/sast-python.yml) | Python | Semgrep, pip-audit, CodeQL |
| [`sbom.yml`](.github/workflows/sbom.yml) | Multi | Syft container SBOM, source dependency scan, Grype vulnerability scanning, license check |

## Workflow Inputs

<details>
<summary><strong>C++ Inputs</strong> (56 inputs)</summary>

**Core:**

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image with clang-tidy, cppcheck, and compile_commands.json |
| `compile_commands_path` | `build` | Path to compile_commands.json inside the container |
| `source_mount` | `/workspace/src` | Where repo source is mounted inside the container |
| `source_setup` | `''` | Shell command to source before tools (e.g., ROS2 setup.bash) |
| `runner` | `ubuntu-latest` | Runner labels as JSON |
| `file_extensions` | `cpp hpp h cc cxx` | Space-separated C++ file extensions to check |
| `exclude_file` | `''` | Path to file listing excluded paths (one per line, `#` comments) |
| `pre_analysis_script` | `''` | Script to run inside Docker before analysis |
| `build_cache_key` | `''` | Cache key for build artifacts (empty = no caching) |
| `build_cache_paths` | `build install` | Space-separated paths to cache |
| `checkout_submodules` | `false` | Pass to actions/checkout submodules (false, true, recursive) |
| `select_jobs` | `all` | Comma-separated jobs to run (all, clang-tidy, cppcheck, coverage, tsan, sanitizers, iwyu, clang-format, doctest, file-naming, cout-ban, new-delete-ban, flawfinder, shellcheck, hadolint) |
| `base_ref` | `''` | Base branch for diff (fallback when github.base_ref is empty) |

**clang-tidy:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_clang_tidy` | `true` | Enable clang-tidy analysis |
| `clang_tidy_config` | `''` | Path to .clang-tidy config (empty = use repo default) |
| `clang_tidy_jobs` | `4` | Parallel clang-tidy jobs inside Docker |

**cppcheck:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_cppcheck` | `true` | Enable cppcheck analysis |
| `cppcheck_suppress` | `''` | Path to cppcheck suppressions file |
| `cppcheck_includes` | `''` | Space-separated include directories |
| `cppcheck_include_file` | `''` | Path to file containing include dirs (one per line) |
| `cppcheck_std` | `c++23` | C++ standard for cppcheck |
| `cppcheck_inconclusive` | `false` | Enable --inconclusive mode (may produce false positives) |
| `cppcheck_strict` | `false` | Use --error-exitcode=1 for native cppcheck error handling |

**clang-format:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_clang_format` | `false` | Enable clang-format check (opt-in) |
| `clang_format_config` | `''` | Path to .clang-format config |

**Flawfinder:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_flawfinder` | `false` | Enable flawfinder CWE lexical scan (opt-in) |
| `flawfinder_min_level` | `2` | Minimum flawfinder finding level (1-5) |
| `enable_sarif` | `false` | Upload SARIF to GitHub Security tab |

**ShellCheck:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_shellcheck` | `false` | Enable ShellCheck for shell scripts (opt-in) |
| `shellcheck_severity` | `warning` | Minimum severity: error, warning, info, style |

**Hadolint:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_hadolint` | `false` | Enable Hadolint for Dockerfiles (opt-in) |
| `hadolint_config` | `''` | Path to .hadolint.yaml config file |

**Sanitizers (ASan/UBSan):**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_sanitizers` | `false` | Enable ASan/UBSan test job (opt-in) |
| `sanitizer_script` | `''` | Script to build+test with sanitizers |
| `sanitizer_suppressions` | `''` | Path to LSAN suppressions file |
| `sanitizer_packages` | `''` | Space-separated packages to test (empty = all) |

**ThreadSanitizer:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_tsan` | `false` | Enable TSan test job (opt-in, mutually exclusive with ASan) |
| `tsan_script` | `''` | Script to build+test with TSan |
| `tsan_suppressions` | `''` | Path to TSan suppressions file |
| `tsan_packages` | `''` | Space-separated packages to test with TSan (empty = all) |

**Coverage:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_coverage` | `false` | Enable gcov/lcov coverage reporting (opt-in) |
| `coverage_script` | `''` | Script to build+test with coverage and collect lcov |
| `coverage_packages` | `''` | Space-separated packages to measure (empty = all) |
| `coverage_threshold` | `0` | Minimum overall line coverage % (0 = no threshold) |
| `coverage_diff_threshold` | `0` | Minimum coverage % for changed lines via diff-cover (0 = disabled) |
| `coverage_diff_report` | `false` | Generate diff-cover markdown report as artifact |

**IWYU:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_iwyu` | `false` | Enable Include-What-You-Use analysis (opt-in) |
| `iwyu_script` | `''` | Script to run IWYU analysis |
| `iwyu_mapping_file` | `''` | Path to IWYU mapping file (.imp) |

**Naming & Banned Patterns:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_file_naming` | `false` | Enable snake_case file naming check (opt-in) |
| `file_naming_exceptions` | `''` | Path to naming exception regexes |
| `file_naming_allowed_prefixes` | `_` | Allowed prefixes for file names |
| `enforce_doctest` | `false` | Require doctest instead of gtest (opt-in) |
| `test_file_pattern` | `test` | Grep pattern to identify test files |
| `ban_cout` | `false` | Ban cout/cerr/printf in non-test files (opt-in) |
| `ban_new` | `false` | Ban raw new/delete in non-test files (opt-in) |

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

<details>
<summary><strong>SBOM Inputs</strong> (8 inputs)</summary>

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image to scan |
| `source_sbom_script` | `''` | Path to source-level SBOM generation script (empty = skip) |
| `grype_fail_on` | `''` | Fail on severity: "" = report-only, "critical", "high", "medium", "low" |
| `grype_ignore_file` | `''` | Path to .grype.yaml ignore file |
| `checkout_submodules` | `false` | Checkout submodules for source SBOM (true/false/recursive) |
| `license_policy_file` | `''` | Path to license policy YAML (empty = skip license check) |
| `license_check_script` | `''` | Path to license check Python script in caller repo |
| `runner` | `ubuntu-latest` | Runner labels as JSON |

</details>

## Full-Featured C++ Example

```yaml
jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
      compile_commands_path: build
      source_mount: /workspace/src
      source_setup: 'source /opt/ros/humble/setup.bash'
      pre_analysis_script: .github/scripts/pre-analysis.sh
      cppcheck_suppress: cppcheck.suppress
      cppcheck_std: c++23
      cppcheck_strict: true
      enable_clang_format: true
      enable_flawfinder: true
      enable_shellcheck: true
      enable_hadolint: true
      enable_sanitizers: true
      sanitizer_script: .github/scripts/sanitizer-tests.sh
      enable_tsan: true
      tsan_script: .github/scripts/tsan-tests.sh
      enable_coverage: true
      coverage_script: .github/scripts/coverage-tests.sh
      enable_iwyu: true
      iwyu_script: .github/scripts/iwyu-analysis.sh
      enforce_doctest: true
      ban_cout: true
      ban_new: true
      enable_file_naming: true
      enable_sarif: true
      runner: '[\"self-hosted\",\"X64\",\"Linux\"]'
    permissions:
      contents: read
      pull-requests: write
      security-events: write

  sbom:
    uses: PavelGuzenfeld/standard/.github/workflows/sbom.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
      source_sbom_script: .github/scripts/generate_source_sbom.py
      grype_fail_on: ''
      license_policy_file: .license-policy.yml
    permissions:
      contents: read
      pull-requests: write
      packages: read
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
  cpp-quality.yml           Reusable C++ quality workflow (56 inputs, 15+ opt-in checks)
  python-quality.yml        Reusable Python quality workflow (ruff/flake8, pytest, diff-cover)
  sast-python.yml           Reusable Python SAST workflow (Semgrep, pip-audit, CodeQL)
  sbom.yml                  Reusable SBOM & supply chain workflow (Syft, Grype, license check)
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
  VERSIONING.md             SemVer policy and bump rules
AGENTS.md                   AI agent instructions for contributing to this repo
src/calculator.py           Python demo module
```

## How It Works

All workflows detect changed files using `git diff --name-only --diff-filter=ACMR` against the PR base branch. Only those files are linted/analyzed, so pre-existing issues in untouched code never block PRs.

Each workflow posts a summary comment on the PR with a hidden HTML marker. On subsequent pushes, the same comment is updated instead of creating duplicates.

C++ tools run inside the caller's Docker image, so they see the exact toolchain, headers, and `compile_commands.json` the project uses.

## License

MIT License - see [LICENSE](LICENSE).
