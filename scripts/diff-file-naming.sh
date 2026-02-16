#!/usr/bin/env bash
# diff-file-naming.sh — Check that changed file/directory names follow snake_case convention.
# Outputs GitHub Actions annotations (::error) for naming violations.
#
# Usage:
#   diff-file-naming.sh <base_branch> [exceptions_file]
#
# Arguments:
#   base_branch       Base branch to diff against (e.g., origin/main)
#   exceptions_file   Path to file with additional exception regexes (one per line)
#
# Environment variables (all optional):
#   NAMING_ALLOWED_PREFIXES   Space-separated allowed prefixes (default: "_")
#                             e.g., "_" allows _bindings.so, "__" allows __init__.py

set -euo pipefail

BASE_BRANCH="${1:?Usage: diff-file-naming.sh <base_branch> [exceptions_file]}"
EXCEPTIONS_FILE="${2:-}"
ALLOWED_PREFIXES="${NAMING_ALLOWED_PREFIXES:-_}"

# Built-in exception filenames (exact match, case-sensitive)
BUILTIN_EXEMPT_FILES=(
    "CMakeLists.txt"
    "Dockerfile"
    "README.md"
    "CLAUDE.md"
    "CHANGELOG.md"
    "CONTRIBUTING.md"
    "LICENSE"
    "Makefile"
    "Doxyfile"
    "package.xml"
    "pyproject.toml"
    "setup.py"
    "setup.cfg"
    "Cargo.toml"
    "Cargo.lock"
)

# Built-in exception filename patterns (regex, matched against filename)
BUILTIN_EXEMPT_PATTERNS=(
    '^requirements.*\.txt$'
    '^\.'                           # dotfiles (.gitignore, .clang-tidy, etc.)
    '^__init__\.py$'
    '^__main__\.py$'
    '^__pycache__$'
    '^py\.typed$'
)

# Built-in exception path prefixes (matched against full path)
BUILTIN_EXEMPT_PATH_PATTERNS=(
    '^\.'                           # dotdirs (.github/, .vscode/, etc.)
)

# snake_case pattern: starts with lowercase letter, then lowercase letters, digits, underscores
SNAKE_CASE_PATTERN='^[a-z][a-z0-9_]*$'

# Load user exceptions from file
USER_EXCEPTIONS=()
if [ -n "$EXCEPTIONS_FILE" ] && [ -f "$EXCEPTIONS_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | xargs)
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        USER_EXCEPTIONS+=("$line")
    done < "$EXCEPTIONS_FILE"
fi

# Get changed files (Added, Copied, Modified, Renamed)
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- 2>/dev/null || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No files changed — skipping file naming check."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Checking file naming conventions on $FILE_COUNT changed file(s)..."

# Check if a segment is exempt via built-in filename exceptions
is_exempt_filename() {
    local name="$1"
    for exempt in "${BUILTIN_EXEMPT_FILES[@]}"; do
        if [ "$name" = "$exempt" ]; then
            return 0
        fi
    done
    return 1
}

# Check if a segment matches built-in exempt patterns
is_exempt_pattern() {
    local name="$1"
    for pattern in "${BUILTIN_EXEMPT_PATTERNS[@]}"; do
        if echo "$name" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

# Check if a path segment matches built-in path prefix exemptions
is_exempt_path_segment() {
    local segment="$1"
    for pattern in "${BUILTIN_EXEMPT_PATH_PATTERNS[@]}"; do
        if echo "$segment" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

# Check if a segment matches user-provided exceptions
is_user_exception() {
    local name="$1"
    for pattern in "${USER_EXCEPTIONS[@]}"; do
        if echo "$name" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

# Check if a name matches snake_case, accounting for allowed prefixes
is_snake_case() {
    local name="$1"

    # Direct match
    if echo "$name" | grep -qE "$SNAKE_CASE_PATTERN"; then
        return 0
    fi

    # Try stripping allowed prefixes
    for prefix in $ALLOWED_PREFIXES; do
        if [[ "$name" == "${prefix}"* ]]; then
            local stripped="${name#$prefix}"
            if [ -n "$stripped" ] && echo "$stripped" | grep -qE "$SNAKE_CASE_PATTERN"; then
                return 0
            fi
        fi
    done

    return 1
}

VIOLATIONS=0

while IFS= read -r filepath; do
    # Split path into segments
    IFS='/' read -ra SEGMENTS <<< "$filepath"
    SEGMENT_COUNT=${#SEGMENTS[@]}

    for i in "${!SEGMENTS[@]}"; do
        segment="${SEGMENTS[$i]}"
        is_last=$(( i == SEGMENT_COUNT - 1 ))

        # Skip exempt path segments (dotdirs like .github)
        if is_exempt_path_segment "$segment"; then
            # Skip this segment AND all children (break out of segment loop)
            break
        fi

        if [ "$is_last" -eq 1 ]; then
            # This is the filename — check the full name first for exemptions
            if is_exempt_filename "$segment"; then
                continue
            fi
            if is_exempt_pattern "$segment"; then
                continue
            fi
            if [ ${#USER_EXCEPTIONS[@]} -gt 0 ] && is_user_exception "$segment"; then
                continue
            fi

            # Extract name without extension for snake_case check
            name_without_ext="${segment%.*}"
            # Handle files with no extension
            if [ "$name_without_ext" = "$segment" ]; then
                name_without_ext="$segment"
            fi
        else
            # This is a directory name
            if is_exempt_pattern "$segment"; then
                continue
            fi
            if [ ${#USER_EXCEPTIONS[@]} -gt 0 ] && is_user_exception "$segment"; then
                continue
            fi
            name_without_ext="$segment"
        fi

        # Check snake_case
        if ! is_snake_case "$name_without_ext"; then
            echo "::error file=${filepath}::File naming violation: '${segment}' is not snake_case (path: ${filepath})"
            VIOLATIONS=$((VIOLATIONS + 1))
            # Only report the first violation per file path
            break
        fi
    done
done <<< "$CHANGED_FILES"

echo ""
echo "File naming check complete: $VIOLATIONS violation(s) found."

if [ "$VIOLATIONS" -gt 0 ]; then
    exit 1
fi

exit 0
