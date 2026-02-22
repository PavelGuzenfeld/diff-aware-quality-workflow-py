#!/usr/bin/env bash
# diff-iwyu.sh — Run Include-What-You-Use only on files changed in the PR.
# Outputs GitHub Actions annotations and a summary report.
#
# Usage:
#   diff-iwyu.sh <base_branch> <compile_commands_dir> [extensions] [mapping_file]
#
# Arguments:
#   base_branch           Base branch to diff against (e.g., origin/main)
#   compile_commands_dir  Directory containing compile_commands.json
#   extensions            Space-separated list of extensions (default: "cpp hpp h cc cxx")
#   mapping_file          Path to IWYU mapping file (.imp)
#
# Options:
#   --strict              Exit 1 if any IWYU suggestions found (default: exit 0 with report)
#   -h, --help            Show this help message

set -euo pipefail

STRICT=false

# Parse flags first
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --strict)  STRICT=true ;;
        -h|--help)
            echo "Usage: $0 <base_branch> <compile_commands_dir> [extensions] [mapping_file]"
            echo ""
            echo "Run Include-What-You-Use only on files changed vs. the base branch."
            echo ""
            echo "Arguments:"
            echo "  base_branch           Base branch to diff against (e.g., origin/main)"
            echo "  compile_commands_dir  Directory containing compile_commands.json"
            echo "  extensions            Space-separated file extensions (default: \"cpp hpp h cc cxx\")"
            echo "  mapping_file          Path to IWYU mapping file (.imp)"
            echo ""
            echo "Options:"
            echo "  --strict              Exit 1 if IWYU suggests any changes (default: report-only)"
            echo "  -h, --help            Show this help message"
            exit 0
            ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done

BASE_BRANCH="${POSITIONAL[0]:?Usage: $0 <base_branch> <compile_commands_dir> [extensions] [mapping_file]}"
COMPILE_COMMANDS="${POSITIONAL[1]:?Usage: $0 <base_branch> <compile_commands_dir> [extensions] [mapping_file]}"
EXTENSIONS="${POSITIONAL[2]:-cpp hpp h cc cxx}"
MAPPING_FILE="${POSITIONAL[3]:-}"

# Build grep pattern from extensions: \.(cpp|hpp|h|cc|cxx)$
EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

# Get changed C++ files (Added, Copied, Modified, Renamed)
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No C++ files changed — skipping IWYU."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Running Include-What-You-Use on $FILE_COUNT changed file(s)..."

# Build IWYU arguments
IWYU_ARGS=("-p" "$COMPILE_COMMANDS")

if [ -n "$MAPPING_FILE" ] && [ -f "$MAPPING_FILE" ]; then
    IWYU_ARGS+=("-Xiwyu" "--mapping_file=$MAPPING_FILE")
fi

ADD_COUNT=0
REMOVE_COUNT=0

while IFS= read -r file; do
    [ -f "$file" ] || continue
    echo "  IWYU: $file"

    # IWYU writes diagnostics to stderr, always exits non-zero when it has suggestions
    OUTPUT=$(include-what-you-use "${IWYU_ARGS[@]}" "$file" 2>&1 || true)

    if [ -n "$OUTPUT" ]; then
        # Check for "should add" / "should remove" suggestions
        if echo "$OUTPUT" | grep -q "should add these lines:"; then
            ADD_COUNT=$((ADD_COUNT + 1))
            echo "$OUTPUT" | grep -A 100 "should add these lines:" | grep -E '^\s*#include' | while IFS= read -r line; do
                echo "::warning file=${file}::IWYU: missing include: ${line}"
            done
        fi

        if echo "$OUTPUT" | grep -q "should remove these lines:"; then
            REMOVE_COUNT=$((REMOVE_COUNT + 1))
            echo "$OUTPUT" | grep -A 100 "should remove these lines:" | grep -E '^\s*-\s*#include' | while IFS= read -r line; do
                echo "::warning file=${file}::IWYU: unnecessary include: ${line}"
            done
        fi
    fi
done <<< "$CHANGED_FILES"

echo ""
echo "=== IWYU Summary ==="
echo "Files with missing includes: $ADD_COUNT"
echo "Files with unnecessary includes: $REMOVE_COUNT"

if $STRICT && [ $((ADD_COUNT + REMOVE_COUNT)) -gt 0 ]; then
    echo "IWYU: $((ADD_COUNT + REMOVE_COUNT)) file(s) with include suggestions (strict mode)."
    exit 1
fi

echo "NOTE: This check is non-blocking (report-only). Use --strict to enforce."
exit 0
