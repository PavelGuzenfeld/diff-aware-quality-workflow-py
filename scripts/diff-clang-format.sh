#!/usr/bin/env bash
# diff-clang-format.sh — Run clang-format --dry-run only on files changed in the PR.
# Outputs GitHub Actions annotations (::error) for formatting violations.
#
# Usage:
#   diff-clang-format.sh <base_branch> [extensions]
#
# Arguments:
#   base_branch   Base branch to diff against (e.g., origin/main)
#   extensions    Space-separated list of extensions (default: "cpp hpp h cc cxx")
#
# Environment variables (all optional):
#   CLANG_FORMAT_CONFIG   Path to .clang-format config file

set -euo pipefail

BASE_BRANCH="${1:?Usage: diff-clang-format.sh <base_branch> [extensions]}"
EXTENSIONS="${2:-cpp hpp h cc cxx}"
CONFIG_FILE="${CLANG_FORMAT_CONFIG:-}"

# Build grep pattern from extensions: \.(cpp|hpp|h|cc|cxx)$
EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

# Get changed C++ files (Added, Copied, Modified, Renamed)
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No C++ files changed — skipping clang-format."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Running clang-format on $FILE_COUNT changed file(s)..."

FORMAT_ARGS=("--dry-run" "--Werror")

if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    FORMAT_ARGS+=("--style=file:$CONFIG_FILE")
fi

VIOLATIONS=0

while IFS= read -r file; do
    [ -f "$file" ] || continue

    # Run clang-format --dry-run --Werror; it exits non-zero on formatting violations
    OUTPUT=$(clang-format "${FORMAT_ARGS[@]}" "$file" 2>&1 || true)

    if [ -n "$OUTPUT" ]; then
        echo "$OUTPUT"

        # Parse clang-format output into GitHub annotations
        # Format varies but typically: file:line:col: warning: code should be clang-formatted
        echo "$OUTPUT" | grep -E '^.+:[0-9]+:[0-9]+:' | while IFS= read -r line; do
            ann_file=$(echo "$line" | cut -d: -f1)
            ann_line=$(echo "$line" | cut -d: -f2)
            ann_col=$(echo "$line" | cut -d: -f3)
            message=$(echo "$line" | cut -d: -f4-)
            echo "::error file=${ann_file},line=${ann_line},col=${ann_col}::clang-format:${message}"
        done

        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done <<< "$CHANGED_FILES"

echo ""
echo "clang-format complete: $VIOLATIONS file(s) with formatting violations."

if [ "$VIOLATIONS" -gt 0 ]; then
    exit 1
fi

exit 0
