#!/usr/bin/env bash
set -euo pipefail

# check-hardening.sh — Verify ELF binary hardening properties using readelf.
#
# Usage: check-hardening.sh <path_or_glob>... [--skip check_name]...
#
# Checks per binary:
#   1. PIE        — ELF type is DYN (shared libs skip this — always DYN)
#   2. RELRO      — GNU_RELRO segment present
#   3. BIND_NOW   — BIND_NOW in dynamic section (Full RELRO)
#   4. CANARY     — __stack_chk_fail symbol present
#   5. FORTIFY    — __*_chk symbol present (warning only — tiny binaries may lack these)
#   6. NX         — GNU_STACK without execute flag
#
# Options:
#   --skip <check>   Skip a check (pie, relro, bindnow, canary, fortify, nx)
#                    May be repeated.
#
# Exit code: 0 = all pass, 1 = violations found

usage() {
    echo "Usage: $0 <path_or_glob>... [--skip check_name]..."
    echo ""
    echo "Verify ELF binary hardening properties using readelf."
    echo ""
    echo "Arguments:"
    echo "  <path_or_glob>   One or more paths or globs to ELF binaries"
    echo ""
    echo "Options:"
    echo "  --skip <check>   Skip a check: pie, relro, bindnow, canary, fortify, nx"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Checks:"
    echo "  pie       ELF type is DYN (Position Independent Executable)"
    echo "  relro     GNU_RELRO segment present (Partial or Full RELRO)"
    echo "  bindnow   BIND_NOW in dynamic section (Full RELRO)"
    echo "  canary    __stack_chk_fail symbol present (stack protector)"
    echo "  fortify   __*_chk symbol present (FORTIFY_SOURCE) — warning only"
    echo "  nx        GNU_STACK without execute flag (non-executable stack)"
    exit 1
}

# Parse arguments
SKIP_CHECKS=()
PATHS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip)
            [[ $# -lt 2 ]] && { echo "Error: --skip requires a check name"; exit 1; }
            SKIP_CHECKS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            PATHS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
    echo "Error: No paths specified."
    echo ""
    usage
fi

is_skipped() {
    local check="$1"
    for s in "${SKIP_CHECKS[@]+"${SKIP_CHECKS[@]}"}"; do
        [[ "$s" == "$check" ]] && return 0
    done
    return 1
}

# Expand globs and collect ELF binaries
BINARIES=()
for pattern in "${PATHS[@]}"; do
    # shellcheck disable=SC2086
    for file in $pattern; do
        [[ -f "$file" ]] || continue
        # Check if it's an ELF file
        if file "$file" 2>/dev/null | grep -q "ELF"; then
            BINARIES+=("$file")
        fi
    done
done

if [[ ${#BINARIES[@]} -eq 0 ]]; then
    echo "Error: No ELF binaries found matching the given paths."
    exit 1
fi

echo "Checking ${#BINARIES[@]} ELF binary(ies)..."
echo ""

FAILURES=0
WARNINGS=0

for binary in "${BINARIES[@]}"; do
    echo "--- $binary ---"
    BIN_FAIL=0

    # Determine if this is a shared library
    IS_SHARED=false
    if file "$binary" 2>/dev/null | grep -q "shared object"; then
        IS_SHARED=true
    fi

    # 1. PIE check — ELF type must be DYN
    if ! is_skipped "pie"; then
        if $IS_SHARED; then
            echo "  PIE: SKIP (shared library — always DYN)"
        else
            ELF_TYPE=$(readelf -h "$binary" 2>/dev/null | grep -oP 'Type:\s+\K\S+' || echo "UNKNOWN")
            if [[ "$ELF_TYPE" == "DYN" ]]; then
                echo "  PIE: PASS (type: DYN)"
            else
                echo "  PIE: FAIL (type: $ELF_TYPE — expected DYN)"
                BIN_FAIL=1
            fi
        fi
    fi

    # 2. RELRO check — GNU_RELRO segment present
    if ! is_skipped "relro"; then
        if readelf -l "$binary" 2>/dev/null | grep -q "GNU_RELRO"; then
            echo "  RELRO: PASS (GNU_RELRO segment present)"
        else
            echo "  RELRO: FAIL (no GNU_RELRO segment)"
            BIN_FAIL=1
        fi
    fi

    # 3. BIND_NOW check — Full RELRO
    if ! is_skipped "bindnow"; then
        if readelf -d "$binary" 2>/dev/null | grep -qE '\(BIND_NOW\)'; then
            echo "  BIND_NOW: PASS (Full RELRO)"
        else
            echo "  BIND_NOW: FAIL (no BIND_NOW — only Partial RELRO)"
            BIN_FAIL=1
        fi
    fi

    # 4. Stack canary check — __stack_chk_fail symbol
    if ! is_skipped "canary"; then
        if readelf -s "$binary" 2>/dev/null | grep -q "__stack_chk_fail"; then
            echo "  CANARY: PASS (__stack_chk_fail present)"
        else
            echo "  CANARY: FAIL (no __stack_chk_fail — stack protector missing)"
            BIN_FAIL=1
        fi
    fi

    # 5. FORTIFY check — __*_chk symbols (warning only)
    if ! is_skipped "fortify"; then
        if readelf -s "$binary" 2>/dev/null | grep -qE "__\w+_chk"; then
            echo "  FORTIFY: PASS (__*_chk symbols present)"
        else
            echo "  FORTIFY: WARN (no __*_chk symbols — binary may not use fortifiable functions)"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    # 6. NX check — GNU_STACK without execute flag
    if ! is_skipped "nx"; then
        STACK_LINE=$(readelf -l "$binary" 2>/dev/null | grep "GNU_STACK" || true)
        if [[ -z "$STACK_LINE" ]]; then
            echo "  NX: FAIL (no GNU_STACK segment)"
            BIN_FAIL=1
        elif echo "$STACK_LINE" | grep -qE 'RWE'; then
            echo "  NX: FAIL (GNU_STACK has execute flag — stack is executable)"
            BIN_FAIL=1
        else
            echo "  NX: PASS (GNU_STACK without execute flag)"
        fi
    fi

    if [[ $BIN_FAIL -gt 0 ]]; then
        FAILURES=$((FAILURES + 1))
    fi
    echo ""
done

echo "========================================"
echo "  Binaries checked: ${#BINARIES[@]}"
echo "  Failures: $FAILURES"
echo "  Warnings: $WARNINGS"
echo "========================================"

if [[ $FAILURES -gt 0 ]]; then
    exit 1
fi
exit 0
