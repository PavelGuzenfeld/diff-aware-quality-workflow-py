#!/usr/bin/env bash
set -euo pipefail

# generate-workflow.sh — Generate .github/workflows/ YAML files with correct inputs.
#
# Usage: generate-workflow.sh [--output-dir PATH] [--non-interactive]
#
# Auto-detects project type from CWD and asks what quality checks are enabled.
# Produces workflow YAML files calling the standard reusable workflows.

OUTPUT_DIR=".github/workflows"
NON_INTERACTIVE=false
STANDARD_REPO="PavelGuzenfeld/standard"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--output-dir PATH] [--non-interactive]"
            echo ""
            echo "Generate .github/workflows/ YAML files for the standard quality workflows."
            echo ""
            echo "Options:"
            echo "  --output-dir PATH     Write YAML files to PATH (default: .github/workflows/)"
            echo "  --non-interactive     Accept all defaults from auto-detection"
            echo "  -h, --help            Show this help message"
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

ask_value() {
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

echo "=== Workflow Generator ==="
echo ""
echo "Auto-detected:"
$detect_cpp    && echo "  C++    (found CMakeLists.txt / package.xml)"
$detect_python && echo "  Python (found pyproject.toml / setup.py / requirements.txt)"
$detect_cpp || $detect_python || echo "  (nothing detected — will ask)"
echo ""

# Language selection
cpp_default=n; $detect_cpp && cpp_default=y
py_default=n; $detect_python && py_default=y

ask "Enable C++ quality workflow?" "$cpp_default" enable_cpp
ask "Enable Python quality workflow?" "$py_default" enable_python

if [[ "$enable_cpp" == "n" && "$enable_python" == "n" ]]; then
    echo "Error: At least one language must be enabled."
    exit 1
fi

# C++ workflow inputs
docker_image=""
compile_commands_path="build"
source_setup=""
enable_clang_format=n
enable_file_naming=n
ban_cout=n
ban_new=n
enforce_doctest=n
enable_flawfinder=n
enable_sanitizers=n
enable_tsan=n
enable_coverage=n
enable_iwyu=n

if [[ "$enable_cpp" == "y" ]]; then
    echo ""
    echo "--- C++ workflow configuration ---"
    ask_value "  Docker image (ghcr.io/org/image:tag):" "" docker_image
    ask_value "  compile_commands.json directory:" "build" compile_commands_path
    ask_value "  Source setup command (e.g., source /opt/ros/humble/setup.bash):" "" source_setup
    echo ""
    echo "--- C++ opt-in checks ---"
    ask "  clang-format?" "n" enable_clang_format
    ask "  File naming enforcement (snake_case)?" "n" enable_file_naming
    ask "  Ban cout/printf?" "n" ban_cout
    ask "  Ban raw new/delete?" "n" ban_new
    ask "  Enforce doctest (ban gtest)?" "n" enforce_doctest
    ask "  Flawfinder CWE scanning?" "n" enable_flawfinder
    ask "  ASAN/UBSAN sanitizer tests?" "n" enable_sanitizers
    ask "  TSAN (ThreadSanitizer) tests?" "n" enable_tsan
    ask "  Code coverage reporting?" "n" enable_coverage
    ask "  Include-What-You-Use (IWYU)?" "n" enable_iwyu
fi

# Python workflow inputs
python_linter="ruff"
enable_semgrep=n
enable_pip_audit=n
enable_codeql=n
enable_sast=n

if [[ "$enable_python" == "y" ]]; then
    echo ""
    echo "--- Python workflow configuration ---"
    ask_value "  Linter (ruff / flake8):" "ruff" python_linter
    echo ""
    echo "--- Python SAST ---"
    ask "  Enable SAST workflow?" "n" enable_sast
    if [[ "$enable_sast" == "y" ]]; then
        ask "    Semgrep?" "y" enable_semgrep
        ask "    pip-audit CVE scanning?" "y" enable_pip_audit
        ask "    CodeQL deep analysis?" "n" enable_codeql
    fi
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

enable_infra=n
[[ "$enable_shellcheck" == "y" || "$enable_hadolint" == "y" || "$enable_cmake_lint" == "y" ]] && enable_infra=y

# --- Create output directory --------------------------------------------------

mkdir -p "$OUTPUT_DIR"

# --- Generate C++ workflow ----------------------------------------------------

if [[ "$enable_cpp" == "y" ]]; then
    CPP_FILE="$OUTPUT_DIR/cpp-quality.yml"

    {
        cat << 'HEADER'
name: C++ Quality

on:
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  quality:
HEADER
        echo "    uses: ${STANDARD_REPO}/.github/workflows/cpp-quality.yml@main"
        echo "    with:"

        # Required inputs
        if [ -n "$docker_image" ]; then
            echo "      docker_image: '$docker_image'"
        else
            echo "      docker_image: ''  # TODO: set your Docker image"
        fi

        # Only emit non-default values
        if [ "$compile_commands_path" != "build" ]; then
            echo "      compile_commands_path: '$compile_commands_path'"
        fi
        if [ -n "$source_setup" ]; then
            echo "      source_setup: '$source_setup'"
        fi

        # Opt-in booleans (only emit when true)
        [[ "$enable_clang_format" == "y" ]] && echo "      enable_clang_format: true"
        [[ "$enable_file_naming" == "y" ]]  && echo "      enable_file_naming: true"
        [[ "$ban_cout" == "y" ]]            && echo "      ban_cout: true"
        [[ "$ban_new" == "y" ]]             && echo "      ban_new: true"
        [[ "$enforce_doctest" == "y" ]]     && echo "      enforce_doctest: true"
        [[ "$enable_flawfinder" == "y" ]]   && echo "      enable_flawfinder: true"
        [[ "$enable_sanitizers" == "y" ]]   && echo "      enable_sanitizers: true"
        [[ "$enable_tsan" == "y" ]]         && echo "      enable_tsan: true"
        [[ "$enable_coverage" == "y" ]]     && echo "      enable_coverage: true"
        [[ "$enable_iwyu" == "y" ]]         && echo "      enable_iwyu: true"

        # Suppress file if it exists
        [ -f "cppcheck.suppress" ] && echo "      cppcheck_suppress: cppcheck.suppress"
        [ -f "naming-exceptions.txt" ] && echo "      file_naming_exceptions: naming-exceptions.txt"

        # Permissions
        echo "    permissions:"
        echo "      actions: read"
        echo "      contents: read"
        echo "      packages: read"
        echo "      pull-requests: write"
        if [[ "$enable_flawfinder" == "y" ]]; then
            echo "      security-events: write"
        fi
    } > "$CPP_FILE"

    echo "Generated: $CPP_FILE"
fi

# --- Generate Python workflow -------------------------------------------------

if [[ "$enable_python" == "y" ]]; then
    PY_FILE="$OUTPUT_DIR/python-quality.yml"

    {
        cat << 'HEADER'
name: Python Quality

on:
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  quality:
HEADER
        echo "    uses: ${STANDARD_REPO}/.github/workflows/python-quality.yml@main"

        # Only emit with: block if non-default values exist
        if [ "$python_linter" != "ruff" ]; then
            echo "    with:"
            echo "      python_linter: '$python_linter'"
        fi

        echo "    permissions:"
        echo "      contents: read"
        echo "      pull-requests: write"
    } > "$PY_FILE"

    echo "Generated: $PY_FILE"
fi

# --- Generate SAST workflow ---------------------------------------------------

if [[ "$enable_sast" == "y" ]]; then
    SAST_FILE="$OUTPUT_DIR/sast-python.yml"

    {
        cat << 'HEADER'
name: Python SAST

on:
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  sast:
HEADER
        echo "    uses: ${STANDARD_REPO}/.github/workflows/sast-python.yml@main"

        # Only emit with: block if any non-default values
        local_has_inputs=false
        # semgrep defaults to true, pip_audit defaults to true, codeql defaults to false
        [[ "$enable_semgrep" == "n" ]] && local_has_inputs=true
        [[ "$enable_pip_audit" == "n" ]] && local_has_inputs=true
        [[ "$enable_codeql" == "y" ]] && local_has_inputs=true

        if $local_has_inputs; then
            echo "    with:"
            [[ "$enable_semgrep" == "n" ]]   && echo "      enable_semgrep: false"
            [[ "$enable_pip_audit" == "n" ]] && echo "      enable_pip_audit: false"
            [[ "$enable_codeql" == "y" ]]    && echo "      enable_codeql: true"
        fi

        echo "    permissions:"
        echo "      actions: read"
        echo "      contents: read"
        echo "      pull-requests: write"
        echo "      security-events: write"
    } > "$SAST_FILE"

    echo "Generated: $SAST_FILE"
fi

# --- Generate infra lint workflow ---------------------------------------------

if [[ "$enable_infra" == "y" ]]; then
    INFRA_FILE="$OUTPUT_DIR/infra-lint.yml"

    {
        cat << 'HEADER'
name: Infrastructure Lint

on:
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  lint:
HEADER
        echo "    uses: ${STANDARD_REPO}/.github/workflows/infra-lint.yml@main"
        echo "    with:"

        [[ "$enable_shellcheck" == "y" ]] && echo "      enable_shellcheck: true"
        [[ "$enable_hadolint" == "y" ]]   && echo "      enable_hadolint: true"
        [[ "$enable_cmake_lint" == "y" ]] && echo "      enable_cmake_lint: true"

        echo "    permissions:"
        echo "      actions: read"
        echo "      contents: read"
        echo "      pull-requests: write"
    } > "$INFRA_FILE"

    echo "Generated: $INFRA_FILE"
fi

# --- Summary ------------------------------------------------------------------

echo ""
echo "=== Workflow Generation Complete ==="
echo ""
echo "Generated files in $OUTPUT_DIR/:"
[[ "$enable_cpp" == "y" ]]   && echo "  - cpp-quality.yml"
[[ "$enable_python" == "y" ]] && echo "  - python-quality.yml"
[[ "$enable_sast" == "y" ]]  && echo "  - sast-python.yml"
[[ "$enable_infra" == "y" ]] && echo "  - infra-lint.yml"
echo ""
echo "Next steps:"
echo "  1. Review the generated files"
if [[ "$enable_cpp" == "y" ]] && [ -z "$docker_image" ]; then
    echo "  2. Set docker_image in cpp-quality.yml"
fi
echo "  3. Commit and push to trigger the workflows"
