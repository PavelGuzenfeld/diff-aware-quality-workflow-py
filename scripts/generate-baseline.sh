#!/usr/bin/env bash
# generate-baseline.sh — Generate suppression/baseline files for incremental adoption.
#
# Usage:
#   generate-baseline.sh <tool> [options]
#
# Supported tools:
#   cppcheck      → generates cppcheck.suppress
#   file-naming   → generates naming-exceptions.txt
#   clang-format  → generates .clang-format-todo
#   flawfinder    → generates .flawfinder-baseline
#
# Run quality tools on all source files and capture existing findings
# so that only new code must pass cleanly.

set -euo pipefail

# --- Defaults -----------------------------------------------------------------

TOOL=""
EXTENSIONS="cpp hpp h cc cxx"
EXCLUDE_FILE=""
OUTPUT=""

# cppcheck-specific
CPPCHECK_INCLUDES=""
CPPCHECK_STD="c++23"

# --- Usage --------------------------------------------------------------------

usage() {
    echo "Usage: $0 <tool> [options]"
    echo ""
    echo "Generate suppression/baseline files for incremental quality adoption."
    echo ""
    echo "Supported tools:"
    echo "  cppcheck      Generate cppcheck.suppress with inline suppressions"
    echo "  file-naming   Generate naming-exceptions.txt from current non-snake_case paths"
    echo "  clang-format  Generate .clang-format-todo list of files needing formatting"
    echo "  flawfinder    Generate .flawfinder-baseline with current findings"
    echo ""
    echo "Common options:"
    echo "  --extensions EXT    Space-separated extensions (default: \"cpp hpp h cc cxx\")"
    echo "  --exclude-file PATH Path to exclude file (one prefix per line)"
    echo "  --output PATH       Override default output file"
    echo ""
    echo "cppcheck options:"
    echo "  --includes PATH     Space-separated include directories"
    echo "  --std STD           C++ standard (default: c++23)"
    echo ""
    echo "Examples:"
    echo "  $0 cppcheck --includes \"include src\" --std c++23"
    echo "  $0 file-naming"
    echo "  $0 clang-format --extensions \"cpp hpp\""
    echo "  $0 flawfinder"
}

# --- Parse arguments ----------------------------------------------------------

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

TOOL="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)       usage; exit 0 ;;
        --extensions)    EXTENSIONS="$2"; shift 2 ;;
        --exclude-file)  EXCLUDE_FILE="$2"; shift 2 ;;
        --output)        OUTPUT="$2"; shift 2 ;;
        --includes)      CPPCHECK_INCLUDES="$2"; shift 2 ;;
        --std)           CPPCHECK_STD="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# --- Helpers ------------------------------------------------------------------

EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

# Collect all source files matching extensions
collect_cpp_files() {
    local files
    files=$(find . -type f | grep -E "$EXT_PATTERN" | sed 's|^\./||' | sort)

    # Apply exclusion filter
    if [ -n "$EXCLUDE_FILE" ] && [ -f "$EXCLUDE_FILE" ]; then
        local patterns=()
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%%#*}"
            line=$(echo "$line" | xargs)
            [ -z "$line" ] && continue
            patterns+=("$line")
        done < "$EXCLUDE_FILE"

        if [ ${#patterns[@]} -gt 0 ]; then
            local filtered=""
            while IFS= read -r fp; do
                [ -z "$fp" ] && continue
                local excl=false
                for p in "${patterns[@]}"; do
                    [[ "$fp" == "$p"* ]] && excl=true && break
                done
                [ "$excl" = false ] && filtered="${filtered}${fp}"$'\n'
            done <<< "$files"
            files=$(echo "$filtered" | sed '/^$/d')
        fi
    fi

    echo "$files"
}

# --- Tool: cppcheck -----------------------------------------------------------

baseline_cppcheck() {
    local output="${OUTPUT:-cppcheck.suppress}"

    echo "Scanning all source files with cppcheck..."

    local files
    files=$(collect_cpp_files)
    if [ -z "$files" ]; then
        echo "No source files found."
        exit 0
    fi

    local file_count
    file_count=$(echo "$files" | wc -l)
    echo "Found $file_count source file(s)."

    # Build cppcheck arguments
    local cppcheck_args=(
        --enable=warning,style,performance,portability
        --template='{file}:{line}:{id}:{message}'
        "--std=$CPPCHECK_STD"
        --inline-suppr
        --error-exitcode=0
    )

    if [ -n "$CPPCHECK_INCLUDES" ]; then
        for dir in $CPPCHECK_INCLUDES; do
            cppcheck_args+=("-I" "$dir")
        done
    fi

    mapfile -t file_array <<< "$files"

    # Run cppcheck and collect findings
    local raw_output
    raw_output=$(cppcheck "${cppcheck_args[@]}" "${file_array[@]}" 2>&1 || true)

    # Extract unique suppression IDs
    local suppressions
    suppressions=$(echo "$raw_output" | grep -E '^.+:[0-9]+:.+:' | awk -F: '{print $3}' | sort -u || true)

    if [ -z "$suppressions" ]; then
        echo "No cppcheck findings — no baseline needed."
        exit 0
    fi

    # Generate suppression file
    {
        echo "# cppcheck.suppress — Generated baseline"
        echo "# These are existing findings grandfathered in for incremental adoption."
        echo "# New code must pass cleanly. Remove suppressions as code is cleaned up."
        echo "#"
        echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""

        # Global suppressions (just IDs)
        while IFS= read -r id; do
            [ -z "$id" ] && continue
            echo "$id"
        done <<< "$suppressions"

        echo ""
        echo "# Per-file suppressions (for targeted cleanup):"
        echo "$raw_output" | grep -E '^.+:[0-9]+:.+:' | awk -F: '{print $3 ":" $1}' | sort -u | while IFS= read -r entry; do
            echo "# $entry"
        done
    } > "$output"

    local count
    count=$(echo "$suppressions" | wc -l)
    echo ""
    echo "Generated baseline: $output"
    echo "  $count unique suppression ID(s)"
    echo "  New code must pass cleanly."
}

# --- Tool: file-naming --------------------------------------------------------

baseline_file_naming() {
    local output="${OUTPUT:-naming-exceptions.txt}"

    echo "Scanning all files for naming violations..."

    SNAKE_CASE='^[a-z][a-z0-9_]*$'
    ALLOWED_PREFIXES="_"

    # Built-in exemptions (same as diff-file-naming.sh)
    BUILTIN_EXEMPT_FILES=(
        "CMakeLists.txt" "Dockerfile" "README.md" "CLAUDE.md"
        "CHANGELOG.md" "CONTRIBUTING.md" "LICENSE" "Makefile"
        "Doxyfile" "package.xml" "pyproject.toml" "setup.py"
        "setup.cfg" "Cargo.toml" "Cargo.lock"
    )
    BUILTIN_EXEMPT_PATTERNS=(
        '^requirements.*\.txt$'
        '^\.'
        '^__init__\.py$'
        '^__main__\.py$'
        '^__pycache__$'
        '^py\.typed$'
        '^[A-Z][A-Z_-]*\.md$'
    )

    is_exempt_filename() {
        local name="$1"
        for exempt in "${BUILTIN_EXEMPT_FILES[@]}"; do
            [ "$name" = "$exempt" ] && return 0
        done
        return 1
    }

    is_exempt_pattern() {
        local name="$1"
        for pattern in "${BUILTIN_EXEMPT_PATTERNS[@]}"; do
            echo "$name" | grep -qE "$pattern" && return 0
        done
        return 1
    }

    is_snake_case() {
        local name="$1"
        echo "$name" | grep -qE "$SNAKE_CASE" && return 0
        for prefix in $ALLOWED_PREFIXES; do
            if [[ "$name" == "${prefix}"* ]]; then
                local stripped="${name#$prefix}"
                [ -n "$stripped" ] && echo "$stripped" | grep -qE "$SNAKE_CASE" && return 0
            fi
        done
        return 1
    }

    # Collect all tracked files
    local all_files
    all_files=$(git ls-files 2>/dev/null || find . -type f | sed 's|^\./||')

    local violations=()

    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue

        IFS='/' read -ra segments <<< "$filepath"
        local seg_count=${#segments[@]}

        for i in "${!segments[@]}"; do
            local segment="${segments[$i]}"
            local is_last=$(( i == seg_count - 1 ))

            # Skip dotdirs and children
            if echo "$segment" | grep -qE '^\.' ; then
                break
            fi

            if [ "$is_last" -eq 1 ]; then
                is_exempt_filename "$segment" && continue
                is_exempt_pattern "$segment" && continue
                local name_without_ext="${segment%.*}"
            else
                is_exempt_pattern "$segment" && continue
                local name_without_ext="$segment"
            fi

            if ! is_snake_case "$name_without_ext"; then
                # Collect the violating segment as an exception pattern
                violations+=("$name_without_ext")
                break
            fi
        done
    done <<< "$all_files"

    if [ ${#violations[@]} -eq 0 ]; then
        echo "All files follow snake_case — no baseline needed."
        exit 0
    fi

    # Deduplicate and generate exceptions file
    local unique_violations
    unique_violations=$(printf '%s\n' "${violations[@]}" | sort -u)

    {
        echo "# naming-exceptions.txt — Generated baseline"
        echo "# These are existing non-snake_case names grandfathered in."
        echo "# New files must follow snake_case. Remove exceptions as files are renamed."
        echo "#"
        echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        while IFS= read -r name; do
            [ -z "$name" ] && continue
            # Escape regex special chars and anchor the match
            local escaped
            escaped=$(echo "$name" | sed 's/[.[\*^$()+?{|]/\\&/g')
            echo "^${escaped}$"
        done <<< "$unique_violations"
    } > "$output"

    local count
    count=$(echo "$unique_violations" | wc -l)
    echo ""
    echo "Generated baseline: $output"
    echo "  $count naming exception(s)"
    echo "  New files must follow snake_case."
}

# --- Tool: clang-format -------------------------------------------------------

baseline_clang_format() {
    local output="${OUTPUT:-.clang-format-todo}"

    echo "Scanning all source files with clang-format..."

    local files
    files=$(collect_cpp_files)
    if [ -z "$files" ]; then
        echo "No source files found."
        exit 0
    fi

    local file_count
    file_count=$(echo "$files" | wc -l)
    echo "Found $file_count source file(s)."

    local violations=()

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ -f "$file" ] || continue

        local check_output
        check_output=$(clang-format --dry-run --Werror "$file" 2>&1 || true)
        if [ -n "$check_output" ]; then
            violations+=("$file")
        fi
    done <<< "$files"

    if [ ${#violations[@]} -eq 0 ]; then
        echo "All files are properly formatted — no baseline needed."
        exit 0
    fi

    {
        echo "# .clang-format-todo — Files needing formatting"
        echo "# These files have existing formatting issues grandfathered in."
        echo "# New and modified code must pass clang-format."
        echo "#"
        echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# Run: clang-format -i <file> to fix individual files"
        echo ""
        printf '%s\n' "${violations[@]}"
    } > "$output"

    echo ""
    echo "Generated baseline: $output"
    echo "  ${#violations[@]} file(s) with formatting issues"
    echo "  New code must pass clang-format."
}

# --- Tool: flawfinder ---------------------------------------------------------

baseline_flawfinder() {
    local output="${OUTPUT:-.flawfinder-baseline}"

    echo "Scanning all source files with flawfinder..."

    local files
    files=$(collect_cpp_files)
    if [ -z "$files" ]; then
        echo "No source files found."
        exit 0
    fi

    local file_count
    file_count=$(echo "$files" | wc -l)
    echo "Found $file_count source file(s)."

    mapfile -t file_array <<< "$files"

    local raw_output
    raw_output=$(flawfinder --columns --dataonly --minlevel=1 "${file_array[@]}" 2>&1 || true)

    local hits
    hits=$(echo "$raw_output" | grep -cE '^.+:[0-9]+:' || true)

    if [ "$hits" -eq 0 ]; then
        echo "No flawfinder findings — no baseline needed."
        exit 0
    fi

    {
        echo "# .flawfinder-baseline — Existing flawfinder findings"
        echo "# These are grandfathered findings for incremental adoption."
        echo "# New code must pass flawfinder cleanly."
        echo "#"
        echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# Findings: $hits"
        echo "#"
        echo "# Format: file:line:col: [level] (CWE-nnn) description"
        echo ""
        echo "$raw_output" | grep -E '^.+:[0-9]+:'
    } > "$output"

    echo ""
    echo "Generated baseline: $output"
    echo "  $hits existing finding(s)"
    echo "  New code must pass flawfinder cleanly."
}

# --- Dispatch -----------------------------------------------------------------

case "$TOOL" in
    cppcheck)      baseline_cppcheck ;;
    file-naming)   baseline_file_naming ;;
    clang-format)  baseline_clang_format ;;
    flawfinder)    baseline_flawfinder ;;
    -h|--help)     usage; exit 0 ;;
    *)
        echo "Error: unknown tool '$TOOL'"
        echo ""
        usage
        exit 1
        ;;
esac
