#!/usr/bin/env bash
set -euo pipefail

# check-dangerous-workflows.sh — Audit GitHub Actions workflow files for injection patterns.
#
# Usage: check-dangerous-workflows.sh [directory]
#
# Scans .yml/.yaml files under the given directory (default: .github/workflows/)
# for patterns that can lead to arbitrary code execution:
#
#   1. pull_request_target with checkout of PR head ref
#   2. PR-controlled inputs (${{ github.event.pull_request.title/body/head.ref }}) in run: steps
#   3. Issue/comment-controlled inputs in run: steps
#
# Exit code: 0 = clean, 1 = findings

SCAN_DIR="${1:-.github/workflows}"

if [ ! -d "$SCAN_DIR" ]; then
    echo "Directory not found: $SCAN_DIR"
    exit 1
fi

VIOLATIONS=0

for file in "$SCAN_DIR"/*.yml "$SCAN_DIR"/*.yaml; do
    [ -f "$file" ] || continue

    # Pattern 1: pull_request_target with checkout of PR ref
    if grep -q 'pull_request_target' "$file"; then
        if grep -qE 'github\.event\.pull_request\.head\.(sha|ref)' "$file"; then
            echo "ERROR: $file: pull_request_target with checkout of PR head ref"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi

    # Pattern 2 & 3: Untrusted input in run: steps
    LINE_NUM=0
    IN_RUN=false
    while IFS= read -r line || [ -n "$line" ]; do
        LINE_NUM=$((LINE_NUM + 1))
        if echo "$line" | grep -qE '^\s+run:\s*[|>]?\s*$' || echo "$line" | grep -qE '^\s+run:\s+\S'; then
            IN_RUN=true
        elif $IN_RUN && echo "$line" | grep -qE '^\s+[a-zA-Z_-]+:' && ! echo "$line" | grep -qE '^\s+#'; then
            IN_RUN=false
        fi

        if $IN_RUN; then
            if echo "$line" | grep -qE '\$\{\{\s*github\.event\.pull_request\.(title|body|head\.ref)\s*\}\}'; then
                echo "ERROR: $file:$LINE_NUM: PR-controlled input in run: step"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
            if echo "$line" | grep -qE '\$\{\{\s*github\.event\.issue\.(title|body)\s*\}\}'; then
                echo "ERROR: $file:$LINE_NUM: issue-controlled input in run: step"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
            if echo "$line" | grep -qE '\$\{\{\s*github\.event\.comment\.body\s*\}\}'; then
                echo "ERROR: $file:$LINE_NUM: comment body in run: step"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
    done < "$file"
done

if [ "$VIOLATIONS" -gt 0 ]; then
    echo ""
    echo "Found $VIOLATIONS dangerous workflow pattern(s)."
    exit 1
else
    echo "No dangerous workflow patterns found in $SCAN_DIR."
    exit 0
fi
