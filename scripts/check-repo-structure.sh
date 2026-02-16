#!/usr/bin/env bash
# check-repo-structure.sh — Validate repository structure against a config file.
# Outputs GitHub Actions annotations (::error, ::warning) for missing items.
#
# Usage:
#   check-repo-structure.sh <config_file> [root_dir]
#
# Arguments:
#   config_file   Path to structure config file
#   root_dir      Root directory to check (default: current directory)
#
# Config format:
#   dir:path/     Required directory (error if missing)
#   dir?path/     Optional directory (warning if missing)
#   file:path     Required file (error if missing)
#   file?path     Optional file (warning if missing)
#
# Lines starting with # and blank lines are ignored.

set -euo pipefail

CONFIG_FILE="${1:?Usage: check-repo-structure.sh <config_file> [root_dir]}"
ROOT_DIR="${2:-.}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "::error::Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "Checking repository structure against $CONFIG_FILE..."
echo "Root directory: $ROOT_DIR"

ERRORS=0
WARNINGS=0

while IFS= read -r line || [ -n "$line" ]; do
    # Strip whitespace
    line=$(echo "$line" | xargs)

    # Skip blank lines and comments
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue

    # Strip inline comments
    line="${line%%#*}"
    line=$(echo "$line" | xargs)
    [ -z "$line" ] && continue

    # Parse entry type and path
    case "$line" in
        dir:*)
            path="${line#dir:}"
            path=$(echo "$path" | xargs)
            if [ ! -d "$ROOT_DIR/$path" ]; then
                echo "::error::Required directory missing: $path"
                ERRORS=$((ERRORS + 1))
            else
                echo "  [OK] dir: $path"
            fi
            ;;
        dir\?*)
            path="${line#dir\?}"
            path=$(echo "$path" | xargs)
            if [ ! -d "$ROOT_DIR/$path" ]; then
                echo "::warning::Optional directory missing: $path"
                WARNINGS=$((WARNINGS + 1))
            else
                echo "  [OK] dir: $path"
            fi
            ;;
        file:*)
            path="${line#file:}"
            path=$(echo "$path" | xargs)
            if [ ! -f "$ROOT_DIR/$path" ]; then
                echo "::error::Required file missing: $path"
                ERRORS=$((ERRORS + 1))
            else
                echo "  [OK] file: $path"
            fi
            ;;
        file\?*)
            path="${line#file\?}"
            path=$(echo "$path" | xargs)
            if [ ! -f "$ROOT_DIR/$path" ]; then
                echo "::warning::Optional file missing: $path"
                WARNINGS=$((WARNINGS + 1))
            else
                echo "  [OK] file: $path"
            fi
            ;;
        *)
            echo "::warning::Unknown config entry: $line"
            WARNINGS=$((WARNINGS + 1))
            ;;
    esac
done < "$CONFIG_FILE"

echo ""
echo "Structure check complete: $ERRORS error(s), $WARNINGS warning(s)."

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
