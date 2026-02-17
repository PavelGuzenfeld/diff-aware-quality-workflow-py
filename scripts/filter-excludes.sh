#!/usr/bin/env bash
# Filter file list using an exclusion file.
# Usage: scripts/filter-excludes.sh <exclude_file> <file_list>
#
# Reads <exclude_file> (one path prefix per line, # comments) and removes
# matching lines from <file_list> (in-place).
#
# Example:
#   scripts/filter-excludes.sh .standards-exclude /tmp/changed_cpp_files.txt

set -euo pipefail

EXCLUDE_FILE="${1:-}"
FILE_LIST="${2:-}"

if [ -z "$EXCLUDE_FILE" ] || [ ! -f "$EXCLUDE_FILE" ]; then
    exit 0
fi

if [ -z "$FILE_LIST" ] || [ ! -f "$FILE_LIST" ]; then
    exit 0
fi

# Parse exclude file: strip comments, trim whitespace, skip blanks
PATTERNS=()
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [ -z "$line" ] && continue
    PATTERNS+=("$line")
done < "$EXCLUDE_FILE"

if [ ${#PATTERNS[@]} -eq 0 ]; then
    exit 0
fi

# Filter: remove lines whose path starts with any exclusion pattern
TEMP=$(mktemp)
while IFS= read -r filepath || [ -n "$filepath" ]; do
    [ -z "$filepath" ] && continue
    excluded=false
    for pattern in "${PATTERNS[@]}"; do
        if [[ "$filepath" == "$pattern"* ]] || [[ "./$filepath" == "./$pattern"* ]]; then
            excluded=true
            break
        fi
    done
    if [ "$excluded" = false ]; then
        echo "$filepath"
    fi
done < "$FILE_LIST" > "$TEMP"

mv "$TEMP" "$FILE_LIST"

BEFORE=$(wc -l < "$FILE_LIST" 2>/dev/null || echo 0)
echo "After exclusion filter: $BEFORE file(s) remaining."
