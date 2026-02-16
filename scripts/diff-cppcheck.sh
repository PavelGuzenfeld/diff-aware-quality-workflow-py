#!/usr/bin/env bash
# diff-cppcheck.sh — Run cppcheck only on files changed in the PR.
# Outputs GitHub Actions annotations (::warning / ::error).
#
# Usage:
#   diff-cppcheck.sh <base_branch> [options]
#
# Arguments:
#   base_branch       Base branch to diff against (e.g., origin/main)
#
# Environment variables (all optional):
#   CPPCHECK_SUPPRESS   Path to suppressions file
#   CPPCHECK_INCLUDES   Space-separated include directories
#   CPPCHECK_STD        C++ standard (default: c++23)
#   CPPCHECK_EXTENSIONS Space-separated file extensions (default: cpp hpp h cc cxx)

set -euo pipefail

BASE_BRANCH="${1:?Usage: diff-cppcheck.sh <base_branch>}"
SUPPRESS_FILE="${CPPCHECK_SUPPRESS:-}"
INCLUDE_DIRS="${CPPCHECK_INCLUDES:-}"
CPP_STD="${CPPCHECK_STD:-c++23}"
EXTENSIONS="${CPPCHECK_EXTENSIONS:-cpp hpp h cc cxx}"

# Build grep pattern from extensions
EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

# Get changed C++ files (Added, Copied, Modified, Renamed)
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No C++ files changed — skipping cppcheck."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Running cppcheck on $FILE_COUNT changed file(s)..."

# Build cppcheck arguments
CPPCHECK_ARGS=(
    --enable=warning,style,performance,portability
    --template=gcc
    "--std=$CPP_STD"
    --inline-suppr
    --error-exitcode=0
)

if [ -n "$SUPPRESS_FILE" ] && [ -f "$SUPPRESS_FILE" ]; then
    CPPCHECK_ARGS+=("--suppressions-list=$SUPPRESS_FILE")
fi

# Add include directories
if [ -n "$INCLUDE_DIRS" ]; then
    for dir in $INCLUDE_DIRS; do
        CPPCHECK_ARGS+=("-I" "$dir")
    done
fi

# Convert file list to array
mapfile -t FILES <<< "$CHANGED_FILES"

# Run cppcheck on all changed files at once
OUTPUT=$(cppcheck "${CPPCHECK_ARGS[@]}" "${FILES[@]}" 2>&1 || true)

ERRORS=0
WARNINGS=0

if [ -n "$OUTPUT" ]; then
    echo "$OUTPUT"

    # Parse cppcheck --template=gcc output into GitHub annotations
    # Format: file:line: severity: message
    echo "$OUTPUT" | grep -E '^.+:[0-9]+:.*(error|warning|style|performance|portability):' | while IFS= read -r line; do
        ann_file=$(echo "$line" | cut -d: -f1)
        ann_line=$(echo "$line" | cut -d: -f2)
        severity=$(echo "$line" | cut -d: -f3 | tr -d ' ')
        message=$(echo "$line" | cut -d: -f4-)

        case "$severity" in
            error)
                echo "::error file=${ann_file},line=${ann_line}::${message}"
                ;;
            *)
                echo "::warning file=${ann_file},line=${ann_line}::${message}"
                ;;
        esac
    done

    ERRORS=$(echo "$OUTPUT" | grep -cE '^.+:[0-9]+:.*error:' || true)
    WARNINGS=$(echo "$OUTPUT" | grep -cE '^.+:[0-9]+:.*(warning|style|performance|portability):' || true)
fi

echo ""
echo "cppcheck complete: $ERRORS error(s), $WARNINGS warning(s)."

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
