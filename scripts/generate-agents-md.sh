#!/usr/bin/env bash
set -euo pipefail

# generate-agents-md.sh — Generate a tailored AGENTS.md for your project
#
# Usage: generate-agents-md.sh [--output PATH] [--non-interactive]
#
# Auto-detects project type from CWD and asks what quality checks are enabled.
# Produces an AGENTS.md with only the relevant sections.

OUTPUT="./AGENTS.md"
NON_INTERACTIVE=false

# Join array elements with a separator
join_by() { local sep="$1"; shift; local first="$1"; shift; printf '%s' "$first" "${@/#/$sep}"; }


while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)   OUTPUT="$2"; shift 2 ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--output PATH] [--non-interactive]"
            echo ""
            echo "  --output PATH        Write AGENTS.md to PATH (default: ./AGENTS.md)"
            echo "  --non-interactive    Accept all defaults from auto-detection"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Auto-detection -----------------------------------------------------------

detect_cpp=false
detect_python=false

[[ -f CMakeLists.txt || -f package.xml ]] && detect_cpp=true
[[ -f pyproject.toml || -f setup.py || -f requirements.txt ]] && detect_python=true

# --- Prompt helpers -----------------------------------------------------------

ask() {
    local prompt="$1" default="$2" var="$3"
    if $NON_INTERACTIVE; then
        eval "$var='$default'"
        return
    fi
    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n] " yn
        yn="${yn:-y}"
    else
        read -rp "$prompt [y/N] " yn
        yn="${yn:-n}"
    fi
    case "$yn" in
        [Yy]*) eval "$var=y" ;;
        *)     eval "$var=n" ;;
    esac
}

ask_choice() {
    local prompt="$1" default="$2" var="$3"
    if $NON_INTERACTIVE; then
        eval "$var='$default'"
        return
    fi
    local answer
    read -rp "$prompt [$default] " answer
    answer="${answer:-$default}"
    eval "$var='$answer'"
}

# --- Interactive questions ----------------------------------------------------

echo "=== AGENTS.md Generator ==="
echo ""
echo "Auto-detected:"
$detect_cpp    && echo "  C++    (found CMakeLists.txt / package.xml)"
$detect_python && echo "  Python (found pyproject.toml / setup.py / requirements.txt)"
$detect_cpp || $detect_python || echo "  (nothing detected — will ask)"
echo ""

# Language selection
cpp_default=n; $detect_cpp && cpp_default=y
py_default=n; $detect_python && py_default=y

ask "Enable C++ checks?" "$cpp_default" enable_cpp
ask "Enable Python checks?" "$py_default" enable_python

if [[ "$enable_cpp" == "n" && "$enable_python" == "n" ]]; then
    echo "Error: At least one language must be enabled."
    exit 1
fi

# C++ opt-in checks
enable_clang_format=n
enable_file_naming=n
enable_ban_cout=n
enable_ban_new=n
enable_enforce_doctest=n
enable_flawfinder=n
enable_sanitizers=n
enable_tsan=n
enable_coverage=n
enable_iwyu=n
logger_replacement="RCLCPP_INFO"

if [[ "$enable_cpp" == "y" ]]; then
    echo ""
    echo "--- C++ opt-in checks ---"
    ask "  clang-format (C++23, 120-col, Allman)?" "n" enable_clang_format
    ask "  File naming enforcement (snake_case)?" "n" enable_file_naming
    ask "  Ban cout/printf (require structured logging)?" "n" enable_ban_cout
    if [[ "$enable_ban_cout" == "y" ]]; then
        ask_choice "  Logger replacement (RCLCPP_INFO / spdlog / custom)?" "RCLCPP_INFO" logger_replacement
    fi
    ask "  Ban raw new/delete (require smart pointers)?" "n" enable_ban_new
    ask "  Enforce doctest (ban gtest/gbenchmark)?" "n" enable_enforce_doctest
    ask "  Flawfinder CWE scanning?" "n" enable_flawfinder
    ask "  ASAN/UBSAN sanitizer tests?" "n" enable_sanitizers
    ask "  TSAN (ThreadSanitizer) tests?" "n" enable_tsan
    ask "  Code coverage reporting?" "n" enable_coverage
    ask "  Include-What-You-Use (IWYU)?" "n" enable_iwyu
fi

# Python options
python_linter="ruff"
enable_semgrep=n
enable_pip_audit=n
enable_codeql=n

if [[ "$enable_python" == "y" ]]; then
    echo ""
    echo "--- Python options ---"
    ask_choice "  Linter (ruff / flake8)?" "ruff" python_linter
    ask "  Semgrep SAST?" "n" enable_semgrep
    ask "  pip-audit CVE scanning?" "n" enable_pip_audit
    ask "  CodeQL deep analysis?" "n" enable_codeql
fi

# Infra lint
enable_shellcheck=n
enable_hadolint=n
enable_cmake_lint=n

echo ""
echo "--- Infrastructure lint ---"
ask "  ShellCheck (shell scripts)?" "n" enable_shellcheck
ask "  Hadolint (Dockerfiles)?" "n" enable_hadolint
if [[ "$enable_cpp" == "y" ]]; then
    ask "  cmake-lint (CMake files)?" "n" enable_cmake_lint
fi

# --- Generate AGENTS.md ------------------------------------------------------

{
# --- Header ---
cat << 'HEADER'
# Agent Instructions — Quality Standard

## Quality Standard

This project uses [diff-aware quality workflows](https://github.com/PavelGuzenfeld/standard) for CI.
Only changed files are checked — but all new and modified code must pass.
HEADER

# --- Always Enforced (C++) ---
if [[ "$enable_cpp" == "y" ]]; then
    cat << 'ALWAYS'

### Always Enforced

- **clang-tidy** — clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability
- **cppcheck** — bug and style checking with project-specific suppressions
ALWAYS
fi

# --- Opt-in list ---
optin_items=()
[[ "$enable_clang_format" == "y" ]]     && optin_items+=('- **clang-format** — C++23, 120-column, 4-space indent, Allman braces')
[[ "$enable_file_naming" == "y" ]]      && optin_items+=('- **File naming** — snake_case for all files and directories')
[[ "$enable_ban_cout" == "y" ]]         && optin_items+=("- **Banned: cout/printf** — use structured logging instead")
[[ "$enable_ban_new" == "y" ]]          && optin_items+=('- **Banned: raw new/delete** — use smart pointers (`std::make_unique`, `std::make_shared`)')
[[ "$enable_enforce_doctest" == "y" ]]  && optin_items+=('- **Banned: gtest/gbenchmark** — use doctest and nanobench')
[[ "$enable_flawfinder" == "y" ]]       && optin_items+=('- **Flawfinder** — CWE lexical security scanning')
[[ "$enable_sanitizers" == "y" ]]       && optin_items+=('- **ASAN/UBSAN** — address and undefined behavior sanitizer tests')
[[ "$enable_tsan" == "y" ]]             && optin_items+=('- **TSAN** — ThreadSanitizer tests')
[[ "$enable_coverage" == "y" ]]         && optin_items+=('- **Coverage** — gcov/lcov test coverage reporting')
[[ "$enable_iwyu" == "y" ]]             && optin_items+=('- **IWYU** — Include-What-You-Use analysis (non-blocking)')
# Identifier naming is always included when C++ is on
[[ "$enable_cpp" == "y" ]]              && optin_items+=('- **Identifier naming** — snake_case functions/variables, PascalCase types, trailing `_` for private members')

if [[ ${#optin_items[@]} -gt 0 ]]; then
    echo ""
    echo "### Opt-in (enabled in this project)"
    echo ""
    for item in "${optin_items[@]}"; do
        echo "$item"
    done
fi

# --- Python header section ---
if [[ "$enable_python" == "y" ]]; then
    echo ""
    echo "### Python"
    echo ""
    echo "- **Linting** — ${python_linter} on changed lines, zero violations required"
    echo "- **Coverage** — pytest + diff-cover, minimum score on changed lines"
    sast_items=()
    [[ "$enable_semgrep" == "y" ]]   && sast_items+=("Semgrep (OWASP Top 10)")
    [[ "$enable_pip_audit" == "y" ]] && sast_items+=("pip-audit (CVE scanning)")
    [[ "$enable_codeql" == "y" ]]    && sast_items+=("CodeQL (deep analysis)")
    if [[ ${#sast_items[@]} -gt 0 ]]; then
        local_sast=$(join_by ", " "${sast_items[@]}")
        echo "- **SAST** — ${local_sast}"
    fi
fi

# --- C++ Conventions ---
if [[ "$enable_cpp" == "y" ]]; then
    echo ""
    echo "## C++ Conventions"

    # File and Directory Naming
    if [[ "$enable_file_naming" == "y" ]]; then
        cat << 'FILENAMING'

### File and Directory Naming

All files and directories must be `snake_case`. Pattern: lowercase letters, digits, underscores.

Valid: `flight_controller.cpp`, `nav_utils/`, `terrain_map.hpp`
Invalid: `FlightController.cpp`, `NavUtils/`, `terrainMap.hpp`

**Built-in exemptions** (no config needed):
`CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, `CHANGELOG.md`, `AGENTS.md`,
dotfiles (`.clang-tidy`, `.gitignore`), `__init__.py`, `requirements*.txt`

**Package directories**: `include/<package_name>/` must also be snake_case.
FILENAMING
    fi

    # Identifier Naming (always for C++)
    cat << 'IDENTNAMING'

### Identifier Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Functions / methods | `snake_case` | `compute_heading()` |
| Variables / parameters | `snake_case` | `max_altitude` |
| Types / classes / structs | `PascalCase` | `FlightController` |
| Private members | `snake_case_` (trailing underscore) | `config_`, `state_` |
| Constants / enums | `UPPER_CASE` | `MAX_RETRIES` |
| Namespaces | `snake_case` | `nav_utils` |
IDENTNAMING

    # Include Convention (always for C++)
    cat << 'INCLUDES'

### Include Convention

```cpp
#pragma once                          // not #ifndef guards
#include <system_headers>             // standard library first
#include "project/package_header.hpp" // project headers second
```

Minimize includes. Forward-declare where possible.
INCLUDES

    # Banned Patterns table
    any_ban=false
    [[ "$enable_ban_cout" == "y" || "$enable_ban_new" == "y" || "$enable_enforce_doctest" == "y" ]] && any_ban=true

    if $any_ban; then
        echo ""
        echo "### Banned Patterns"
        echo ""
        echo "| Pattern | Reason | Alternative |"
        echo "|---------|--------|-------------|"
        if [[ "$enable_ban_cout" == "y" ]]; then
            echo "| \`std::cout\`, \`std::cerr\`, \`printf\`, \`fprintf\`, \`puts\` | No structured logging | Use your project's logger (e.g., \`${logger_replacement}\`) |"
        fi
        if [[ "$enable_ban_new" == "y" ]]; then
            echo "| \`new T\`, \`delete p\` | Memory leaks | \`std::make_unique<T>()\`, \`std::make_shared<T>()\` |"
        fi
        if [[ "$enable_enforce_doctest" == "y" ]]; then
            echo "| \`#include <gtest/gtest.h>\` | Non-standard for this project | \`#include <doctest/doctest.h>\` |"
            echo "| \`#include <benchmark/benchmark.h>\` | Non-standard for this project | \`#include <nanobench.h>\` |"
        fi
        echo ""
        echo "These bans apply to production code only. Test files (matching \`test\` in the path) may have different rules depending on project configuration."
    fi

    # Testing Requirements (always for C++)
    cat << 'TESTING'

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
TESTING

    # Dynamically numbered test categories
    n=8
    if [[ "$enable_sanitizers" == "y" ]]; then
        echo "${n}. **ASan + UBSan** — build and test with address/undefined sanitizers"
        n=$((n + 1))
    fi
    if [[ "$enable_tsan" == "y" ]]; then
        echo "${n}. **TSan** — build and test with thread sanitizer (if multi-threaded)"
        n=$((n + 1))
    fi
    if [[ "$enable_sanitizers" == "y" ]]; then
        echo "${n}. **Release + sanitizers** — verify optimized builds don't introduce UB"
        n=$((n + 1))
    fi
    echo "${n}. **Fuzz harness** — libFuzzer for parsers, serializers, and input handlers"

    # Sanitizer Build Presets
    if [[ "$enable_sanitizers" == "y" || "$enable_tsan" == "y" ]]; then
        echo ""
        echo "### Sanitizer Build Presets"
        echo ""
        echo '```bash'
        [[ "$enable_sanitizers" == "y" ]] && echo "cmake --preset debug-asan    # ASan + UBSan"
        [[ "$enable_tsan" == "y" ]]       && echo "cmake --preset debug-tsan    # ThreadSanitizer"
        [[ "$enable_sanitizers" == "y" ]] && echo "cmake --preset release-asan  # ASan + UBSan at -O2"
        echo '```'
    fi

    # Code Formatting (only if clang-format enabled)
    if [[ "$enable_clang_format" == "y" ]]; then
        cat << 'FORMATTING'

## Code Formatting

### clang-format Settings

- Standard: C++23
- Column limit: 120
- Indent: 4 spaces
- Braces: Allman (opening brace on new line)
- No bin-packing of arguments
FORMATTING
    fi

    # clang-tidy section (always for C++)
    echo ""
    echo "### clang-tidy Checks"
    echo ""
    echo 'Active check groups: `clang-analyzer-*`, `cppcoreguidelines-*`, `modernize-*`, `bugprone-*`, `performance-*`, `readability-*`'
    echo ""
    echo "Run locally before pushing:"
    echo ""
    echo '```bash'
    echo '# Check only files changed vs main'
    echo './scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"'
    echo './scripts/diff-cppcheck.sh origin/main'
    [[ "$enable_clang_format" == "y" ]] && echo './scripts/diff-clang-format.sh origin/main "cpp hpp h"'
    [[ "$enable_file_naming" == "y" ]]  && echo './scripts/diff-file-naming.sh origin/main'
    echo '```'
fi

# --- Python Conventions ---
if [[ "$enable_python" == "y" ]]; then
    echo ""
    echo "## Python Conventions"
    echo ""
    echo "- **Linter**: ${python_linter}"
    if [[ "$python_linter" == "ruff" ]]; then
        echo "- **Formatter**: ruff format or black"
    else
        echo "- **Formatter**: black"
    fi
    echo "- **Test framework**: pytest"
    echo "- **Coverage**: diff-cover (only changed lines must be covered)"
    sast_lines=()
    [[ "$enable_semgrep" == "y" ]]   && sast_lines+=("Semgrep for security")
    [[ "$enable_pip_audit" == "y" ]] && sast_lines+=("pip-audit for CVEs")
    [[ "$enable_codeql" == "y" ]]    && sast_lines+=("CodeQL for deep analysis")
    if [[ ${#sast_lines[@]} -gt 0 ]]; then
        local_sast=$(join_by ", " "${sast_lines[@]}")
        echo "- **SAST**: ${local_sast}"
    fi
    echo "- **Style**: PEP 8, type hints encouraged"
fi

# --- Local Verification ---
echo ""
echo "## Local Verification"
echo ""
echo "Run these before pushing to avoid CI failures:"
echo ""
echo '```bash'

if [[ "$enable_cpp" == "y" ]]; then
    echo "# C++ (inside your Docker dev container)"
    echo './scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"'
    echo './scripts/diff-cppcheck.sh origin/main'
    [[ "$enable_clang_format" == "y" ]] && echo './scripts/diff-clang-format.sh origin/main "cpp hpp h"'
    [[ "$enable_file_naming" == "y" ]]  && echo './scripts/diff-file-naming.sh origin/main naming-exceptions.txt'
fi

if [[ "$enable_python" == "y" ]]; then
    [[ "$enable_cpp" == "y" ]] && echo ""
    echo "# Python"
    echo "${python_linter} check src/ tests/"
    echo "pytest --cov=src tests/"
fi

echo '```'

# --- Customization ---
has_customization=false
[[ "$enable_file_naming" == "y" || "$enable_cpp" == "y" ]] && has_customization=true

if $has_customization; then
    echo ""
    echo "## Customization"
fi

if [[ "$enable_file_naming" == "y" ]]; then
    cat << 'NAMING_EXCEPTIONS'

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
NAMING_EXCEPTIONS
fi

if [[ "$enable_cpp" == "y" ]]; then
    cat << 'CPPCHECK_SUPP'

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
CPPCHECK_SUPP
fi

# --- CI Workflows ---
echo ""
echo "## CI Workflows"
echo ""
echo 'Every project integrating this standard must have a quality workflow in `.github/workflows/`.'

if [[ "$enable_cpp" == "y" ]]; then
    echo ""
    echo "### C++ Workflow"
    echo ""
    echo '- **File**: `cpp-quality.yml` calling the reusable workflow'
    echo '- **Required inputs**: `docker_image`, `compile_commands_path`'
    echo "- **Always enabled**: clang-tidy, cppcheck"

    cpp_optin_names=()
    [[ "$enable_clang_format" == "y" ]]    && cpp_optin_names+=("clang-format")
    [[ "$enable_file_naming" == "y" ]]     && cpp_optin_names+=("file naming")
    [[ "$enable_ban_cout" == "y" ]]        && cpp_optin_names+=("cout/printf ban")
    [[ "$enable_ban_new" == "y" ]]         && cpp_optin_names+=("new/delete ban")
    [[ "$enable_enforce_doctest" == "y" ]] && cpp_optin_names+=("doctest enforcement")
    [[ "$enable_flawfinder" == "y" ]]      && cpp_optin_names+=("flawfinder")
    [[ "$enable_sanitizers" == "y" ]]      && cpp_optin_names+=("ASAN/UBSAN")
    [[ "$enable_tsan" == "y" ]]            && cpp_optin_names+=("TSAN")
    [[ "$enable_coverage" == "y" ]]        && cpp_optin_names+=("coverage")
    [[ "$enable_iwyu" == "y" ]]            && cpp_optin_names+=("IWYU")

    if [[ ${#cpp_optin_names[@]} -gt 0 ]]; then
        local_list=$(join_by ", " "${cpp_optin_names[@]}")
        echo "- **Opt-in enabled**: ${local_list}"
    fi
fi

if [[ "$enable_python" == "y" ]]; then
    echo ""
    echo "### Python Workflow"
    echo ""
    echo "- **File**: \`python-quality.yml\` calling the reusable workflow"
    echo "- **Linter**: ${python_linter}"

    py_sast_names=()
    [[ "$enable_semgrep" == "y" ]]   && py_sast_names+=("Semgrep")
    [[ "$enable_pip_audit" == "y" ]] && py_sast_names+=("pip-audit")
    [[ "$enable_codeql" == "y" ]]    && py_sast_names+=("CodeQL")
    if [[ ${#py_sast_names[@]} -gt 0 ]]; then
        echo "- **SAST** (\`sast-python.yml\`): $(join_by ", " "${py_sast_names[@]}")"
    fi
fi

# Infra lint workflow
infra_names=()
[[ "$enable_shellcheck" == "y" ]] && infra_names+=("ShellCheck")
[[ "$enable_hadolint" == "y" ]]   && infra_names+=("Hadolint")
[[ "$enable_cmake_lint" == "y" ]] && infra_names+=("cmake-lint")

if [[ ${#infra_names[@]} -gt 0 ]]; then
    echo ""
    echo "### Infrastructure Lint"
    echo ""
    echo "- **File**: \`infra-lint.yml\` calling the reusable workflow"
    echo "- **Enabled**: $(join_by ", " "${infra_names[@]}")"
fi

# Optional workflows
echo ""
echo "### Optional Workflows"
echo ""
echo '- `ci-codeql.yml` — GitHub CodeQL analysis'
echo '- `ci-infer.yml` — Facebook Infer static analysis (C++)'
echo '- `ci-fuzz.yml` — libFuzzer continuous fuzzing'
echo '- `ci-multi-compiler.yml` — GCC + Clang multi-compiler builds'

echo ""
echo "### Verification"
echo ""
echo 'Confirm `.github/workflows/` contains the quality workflow for your language(s).'
echo ""
echo "Full setup instructions: see \`INTEGRATION.md\`."

# --- SDLC Process ---
cat << 'SDLC'

## SDLC Process

The standard supports a 4-phase Software Development Lifecycle:

- **Phase 1: Developer workstation** — pre-commit hooks, local diff-aware scripts, sanitizer CMake presets, editor integration
- **Phase 2: PR quality gate** — diff-aware linting, naming checks, banned pattern detection via CI workflows
- **Phase 3: SAST** — Semgrep (Python), CodeQL (C++/Python), Infer (C++), pip-audit (Python)
- **Phase 4: Hardening** — sanitizer builds in CI, fuzzing harnesses, multi-compiler testing

Full documentation: see `SDLC.md`.
SDLC

} > "$OUTPUT"

# --- Summary ------------------------------------------------------------------

echo ""
echo "=== Generated: $OUTPUT ==="
echo ""
echo "Included sections:"
[[ "$enable_cpp" == "y" ]]              && echo "  - C++ quality (clang-tidy, cppcheck — always on)"
[[ "$enable_clang_format" == "y" ]]     && echo "  - clang-format"
[[ "$enable_file_naming" == "y" ]]      && echo "  - File naming (snake_case)"
[[ "$enable_ban_cout" == "y" ]]         && echo "  - Ban cout/printf (logger: $logger_replacement)"
[[ "$enable_ban_new" == "y" ]]          && echo "  - Ban raw new/delete"
[[ "$enable_enforce_doctest" == "y" ]]  && echo "  - Enforce doctest"
[[ "$enable_flawfinder" == "y" ]]       && echo "  - Flawfinder"
[[ "$enable_sanitizers" == "y" ]]       && echo "  - ASAN/UBSAN"
[[ "$enable_tsan" == "y" ]]            && echo "  - TSAN"
[[ "$enable_coverage" == "y" ]]         && echo "  - Coverage"
[[ "$enable_iwyu" == "y" ]]             && echo "  - IWYU"
[[ "$enable_python" == "y" ]]           && echo "  - Python quality ($python_linter)"
[[ "$enable_semgrep" == "y" ]]          && echo "  - Semgrep"
[[ "$enable_pip_audit" == "y" ]]        && echo "  - pip-audit"
[[ "$enable_codeql" == "y" ]]           && echo "  - CodeQL"
[[ "$enable_shellcheck" == "y" ]]       && echo "  - ShellCheck"
[[ "$enable_hadolint" == "y" ]]         && echo "  - Hadolint"
[[ "$enable_cmake_lint" == "y" ]]       && echo "  - cmake-lint"
echo ""
echo "Next steps:"
echo "  1. Review $OUTPUT"
echo "  2. Set up .github/workflows/ to call the reusable workflows"
echo "  3. See INTEGRATION.md for full workflow setup"
