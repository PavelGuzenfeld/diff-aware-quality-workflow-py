#!/usr/bin/env bash
# generate-badges.sh — Output README badge markdown for enabled quality checks.
#
# Usage:
#   generate-badges.sh [--scan-workflows] [--interactive] [--format markdown|html]
#
# Modes:
#   --scan-workflows  (default) Parse .github/workflows/*.yml to detect enabled inputs
#   --interactive     Ask which checks are enabled (same questions as generate-agents-md.sh)

set -euo pipefail

MODE="scan"
FORMAT="markdown"
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scan-workflows)  MODE="scan"; shift ;;
        --interactive)     MODE="interactive"; shift ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --format)          FORMAT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--scan-workflows] [--interactive] [--format markdown|html]"
            echo ""
            echo "Output README badge markdown for enabled quality checks."
            echo ""
            echo "Modes:"
            echo "  --scan-workflows  (default) Parse .github/workflows/*.yml to detect checks"
            echo "  --interactive     Ask which checks are enabled"
            echo ""
            echo "Options:"
            echo "  --non-interactive  Accept defaults (for --interactive mode)"
            echo "  --format FORMAT    Output format: markdown (default) or html"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Badge helpers ------------------------------------------------------------

badge_md() {
    local label="$1" color="$2"
    local encoded_label
    encoded_label=$(echo "$label" | sed 's/ /%20/g; s/-/--/g')
    echo "![${label}](https://img.shields.io/badge/${encoded_label}-enabled-${color})"
}

badge_html() {
    local label="$1" color="$2"
    local encoded_label
    encoded_label=$(echo "$label" | sed 's/ /%20/g; s/-/--/g')
    echo "<img src=\"https://img.shields.io/badge/${encoded_label}-enabled-${color}\" alt=\"${label}\">"
}

emit_badge() {
    local label="$1" color="$2"
    if [ "$FORMAT" = "html" ]; then
        badge_html "$label" "$color"
    else
        badge_md "$label" "$color"
    fi
}

# --- Scan mode ----------------------------------------------------------------

scan_workflows() {
    local workflow_dir=".github/workflows"
    if [ ! -d "$workflow_dir" ]; then
        echo "Error: no $workflow_dir directory found." >&2
        echo "Run from your project root, or use --interactive mode." >&2
        exit 1
    fi

    # Detect enabled features by scanning workflow files
    local cpp_enabled=false
    local python_enabled=false

    # C++ badges
    local clang_tidy=false
    local cppcheck=false
    local clang_format=false
    local file_naming=false
    local ban_cout=false
    local ban_new=false
    local enforce_doctest=false
    local flawfinder=false
    local sanitizers=false
    local tsan=false
    local coverage=false
    local iwyu=false

    # Python badges
    local python_lint=false
    local semgrep=false
    local pip_audit=false
    local codeql=false

    # Infra badges
    local shellcheck=false
    local hadolint=false
    local cmake_lint=false

    for yml in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
        [ -f "$yml" ] || continue
        local content
        content=$(cat "$yml")

        # Detect C++ quality workflow usage
        if echo "$content" | grep -qE 'cpp-quality\.yml'; then
            cpp_enabled=true
            clang_tidy=true
            cppcheck=true

            # Check for opt-in inputs set to true
            echo "$content" | grep -qE 'enable_clang_format:\s*true' && clang_format=true
            echo "$content" | grep -qE 'enable_file_naming:\s*true' && file_naming=true
            echo "$content" | grep -qE 'ban_cout:\s*true' && ban_cout=true
            echo "$content" | grep -qE 'ban_new:\s*true' && ban_new=true
            echo "$content" | grep -qE 'enforce_doctest:\s*true' && enforce_doctest=true
            echo "$content" | grep -qE 'enable_flawfinder:\s*true' && flawfinder=true
            echo "$content" | grep -qE 'enable_sanitizers:\s*true' && sanitizers=true
            echo "$content" | grep -qE 'enable_tsan:\s*true' && tsan=true
            echo "$content" | grep -qE 'enable_coverage:\s*true' && coverage=true
            echo "$content" | grep -qE 'enable_iwyu:\s*true' && iwyu=true
        fi

        # Detect Python quality workflow
        if echo "$content" | grep -qE 'python-quality\.yml'; then
            python_enabled=true
            python_lint=true
        fi

        # Detect Python SAST workflow
        if echo "$content" | grep -qE 'sast-python\.yml'; then
            echo "$content" | grep -qE 'enable_semgrep:\s*true' && semgrep=true
            echo "$content" | grep -qE 'enable_pip_audit:\s*true' && pip_audit=true
            echo "$content" | grep -qE 'enable_codeql:\s*true' && codeql=true
            # Defaults: semgrep and pip_audit are true by default in sast-python.yml
            # If the workflow is used and the inputs are not explicitly set to false, assume defaults
            if ! echo "$content" | grep -qE 'enable_semgrep:'; then
                semgrep=true
            fi
            if ! echo "$content" | grep -qE 'enable_pip_audit:'; then
                pip_audit=true
            fi
        fi

        # Detect infra lint workflow
        if echo "$content" | grep -qE 'infra-lint\.yml'; then
            echo "$content" | grep -qE 'enable_shellcheck:\s*true' && shellcheck=true
            echo "$content" | grep -qE 'enable_hadolint:\s*true' && hadolint=true
            echo "$content" | grep -qE 'enable_cmake_lint:\s*true' && cmake_lint=true
        fi
    done

    # --- Output badges ---
    local any_output=false

    if $cpp_enabled; then
        echo "### C++ Analysis"
        echo ""
        $clang_tidy && emit_badge "clang-tidy" "brightgreen"
        $cppcheck && emit_badge "cppcheck" "brightgreen"
        $flawfinder && emit_badge "flawfinder" "blue"
        $iwyu && emit_badge "IWYU" "blue"
        echo ""
        any_output=true
    fi

    if $clang_format || $file_naming || $ban_cout || $ban_new || $enforce_doctest; then
        echo "### C++ Style"
        echo ""
        $clang_format && emit_badge "clang-format" "brightgreen"
        $file_naming && emit_badge "file naming" "brightgreen"
        $ban_cout && emit_badge "no cout" "orange"
        $ban_new && emit_badge "no raw new" "orange"
        $enforce_doctest && emit_badge "doctest only" "orange"
        echo ""
        any_output=true
    fi

    if $python_enabled; then
        echo "### Python"
        echo ""
        $python_lint && emit_badge "Python lint" "brightgreen"
        echo ""
        any_output=true
    fi

    if $semgrep || $pip_audit || $codeql; then
        echo "### Security"
        echo ""
        $semgrep && emit_badge "Semgrep" "blueviolet"
        $pip_audit && emit_badge "pip-audit" "blueviolet"
        $codeql && emit_badge "CodeQL" "blueviolet"
        echo ""
        any_output=true
    fi

    if $sanitizers || $tsan || $coverage; then
        echo "### Testing"
        echo ""
        $sanitizers && emit_badge "ASAN/UBSAN" "green"
        $tsan && emit_badge "TSAN" "green"
        $coverage && emit_badge "Coverage" "green"
        echo ""
        any_output=true
    fi

    if $shellcheck || $hadolint || $cmake_lint; then
        echo "### Infrastructure"
        echo ""
        $shellcheck && emit_badge "ShellCheck" "yellowgreen"
        $hadolint && emit_badge "Hadolint" "yellowgreen"
        $cmake_lint && emit_badge "cmake-lint" "yellowgreen"
        echo ""
        any_output=true
    fi

    if ! $any_output; then
        echo "No quality workflows detected in $workflow_dir" >&2
        echo "Ensure your workflows call the standard reusable workflows." >&2
        exit 1
    fi
}

# --- Interactive mode ---------------------------------------------------------

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

interactive_mode() {
    echo "=== Badge Generator (Interactive) ===" >&2
    echo "" >&2

    # C++ checks
    ask "clang-tidy?" "y" b_clang_tidy
    ask "cppcheck?" "y" b_cppcheck
    ask "clang-format?" "n" b_clang_format
    ask "file naming?" "n" b_file_naming
    ask "ban cout/printf?" "n" b_ban_cout
    ask "ban new/delete?" "n" b_ban_new
    ask "enforce doctest?" "n" b_enforce_doctest
    ask "flawfinder?" "n" b_flawfinder
    ask "ASAN/UBSAN?" "n" b_sanitizers
    ask "TSAN?" "n" b_tsan
    ask "Coverage?" "n" b_coverage
    ask "IWYU?" "n" b_iwyu

    # Python
    ask "Python lint?" "n" b_python
    ask "Semgrep?" "n" b_semgrep
    ask "pip-audit?" "n" b_pip_audit
    ask "CodeQL?" "n" b_codeql

    # Infra
    ask "ShellCheck?" "n" b_shellcheck
    ask "Hadolint?" "n" b_hadolint
    ask "cmake-lint?" "n" b_cmake_lint

    echo "" >&2

    # C++ Analysis
    if [[ "$b_clang_tidy" == "y" || "$b_cppcheck" == "y" || "$b_flawfinder" == "y" || "$b_iwyu" == "y" ]]; then
        echo "### C++ Analysis"
        echo ""
        [[ "$b_clang_tidy" == "y" ]] && emit_badge "clang-tidy" "brightgreen"
        [[ "$b_cppcheck" == "y" ]] && emit_badge "cppcheck" "brightgreen"
        [[ "$b_flawfinder" == "y" ]] && emit_badge "flawfinder" "blue"
        [[ "$b_iwyu" == "y" ]] && emit_badge "IWYU" "blue"
        echo ""
    fi

    # C++ Style
    if [[ "$b_clang_format" == "y" || "$b_file_naming" == "y" || "$b_ban_cout" == "y" || "$b_ban_new" == "y" || "$b_enforce_doctest" == "y" ]]; then
        echo "### C++ Style"
        echo ""
        [[ "$b_clang_format" == "y" ]] && emit_badge "clang-format" "brightgreen"
        [[ "$b_file_naming" == "y" ]] && emit_badge "file naming" "brightgreen"
        [[ "$b_ban_cout" == "y" ]] && emit_badge "no cout" "orange"
        [[ "$b_ban_new" == "y" ]] && emit_badge "no raw new" "orange"
        [[ "$b_enforce_doctest" == "y" ]] && emit_badge "doctest only" "orange"
        echo ""
    fi

    # Python
    if [[ "$b_python" == "y" ]]; then
        echo "### Python"
        echo ""
        emit_badge "Python lint" "brightgreen"
        echo ""
    fi

    # Security
    if [[ "$b_semgrep" == "y" || "$b_pip_audit" == "y" || "$b_codeql" == "y" ]]; then
        echo "### Security"
        echo ""
        [[ "$b_semgrep" == "y" ]] && emit_badge "Semgrep" "blueviolet"
        [[ "$b_pip_audit" == "y" ]] && emit_badge "pip-audit" "blueviolet"
        [[ "$b_codeql" == "y" ]] && emit_badge "CodeQL" "blueviolet"
        echo ""
    fi

    # Testing
    if [[ "$b_sanitizers" == "y" || "$b_tsan" == "y" || "$b_coverage" == "y" ]]; then
        echo "### Testing"
        echo ""
        [[ "$b_sanitizers" == "y" ]] && emit_badge "ASAN/UBSAN" "green"
        [[ "$b_tsan" == "y" ]] && emit_badge "TSAN" "green"
        [[ "$b_coverage" == "y" ]] && emit_badge "Coverage" "green"
        echo ""
    fi

    # Infra
    if [[ "$b_shellcheck" == "y" || "$b_hadolint" == "y" || "$b_cmake_lint" == "y" ]]; then
        echo "### Infrastructure"
        echo ""
        [[ "$b_shellcheck" == "y" ]] && emit_badge "ShellCheck" "yellowgreen"
        [[ "$b_hadolint" == "y" ]] && emit_badge "Hadolint" "yellowgreen"
        [[ "$b_cmake_lint" == "y" ]] && emit_badge "cmake-lint" "yellowgreen"
        echo ""
    fi
}

# --- Dispatch -----------------------------------------------------------------

case "$MODE" in
    scan)        scan_workflows ;;
    interactive) interactive_mode ;;
esac
