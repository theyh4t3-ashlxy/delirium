#!/usr/bin/env bash
# ==============================================================================
# tests/run_all.sh: Master Test Suite Runner for Quickshell Refactor
# ==============================================================================
# Orchestrates all validation tiers:
#   Tier 1: Static Analysis & Import Validation (tests/test_lint.sh)
#   Tier 2: Schema Consistency & Lossless Persistence (tests/test_schema.py)
#   Tier 3: Isolated Headless Wayland E2E Runtime (tests/test_headless_e2e.sh)
#   Tier 4: Requirement Acceptance Verification (tests/test_requirements.py)
#
# Flags:
#   --bail, -b : Exit immediately upon first failing tier.
#   --tier, -t : Run only the specified tier (1, 2, 3, or 4).
#
# Exit 0: All tiers completed successfully.
# Exit 1: One or more tiers failed.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BAIL=false
TARGET_TIER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bail|-b)
            BAIL=true
            shift
            ;;
        --tier|-t)
            if [[ $# -lt 2 ]]; then
                echo "Error: Option '$1' requires an argument (valid tiers: 1, 2, 3, 4)." >&2
                echo "Usage: $0 [--bail|-b] [--tier|-t 1|2|3|4]" >&2
                exit 1
            fi
            TARGET_TIER="$2"
            shift 2
            ;;
        --tier=*)
            TARGET_TIER="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--bail|-b] [--tier|-t 1|2|3|4]"
            exit 0
            ;;
        *)
            echo "Error: Unrecognized option '$1'" >&2
            echo "Usage: $0 [--bail|-b] [--tier|-t 1|2|3|4]" >&2
            exit 1
            ;;
    esac
done

if [[ -n "$TARGET_TIER" ]]; then
    if [[ "$TARGET_TIER" != "1" && "$TARGET_TIER" != "2" && "$TARGET_TIER" != "3" && "$TARGET_TIER" != "4" ]]; then
        echo "Error: Invalid tier '$TARGET_TIER'. Valid tiers: 1, 2, 3, 4" >&2
        echo "Usage: $0 [--bail|-b] [--tier|-t 1|2|3|4]" >&2
        exit 1
    fi
fi

T1_SCRIPT="$SCRIPT_DIR/test_lint.sh"
T2_SCRIPT="$SCRIPT_DIR/test_schema.py"
T3_SCRIPT="$SCRIPT_DIR/test_headless_e2e.sh"
T4_SCRIPT="$SCRIPT_DIR/test_requirements.py"

echo "========================================================================"
echo " QUICKSHELL VALIDATION & TEST SUITE"
echo " Target: $PROJECT_DIR"
echo " Date:   $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "========================================================================"

RESULTS=()
STATUS_NAMES=()
DURATIONS=()

run_tier() {
    local tier_num="$1"
    local tier_name="$2"
    local cmd="$3"

    if [[ -n "$TARGET_TIER" && "$TARGET_TIER" != "$tier_num" ]]; then
        return 0
    fi

    echo ""
    echo ">>> Running Tier $tier_num: $tier_name..."
    local start_time
    start_time=$(date +%s)
    
    local exit_code=0
    eval "$cmd" || exit_code=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    STATUS_NAMES+=("Tier $tier_num: $tier_name")
    DURATIONS+=("${duration}s")

    if [[ $exit_code -eq 0 ]]; then
        RESULTS+=("PASS")
        echo ">>> Tier $tier_num PASSED (${duration}s)"
    else
        RESULTS+=("FAIL")
        echo ">>> Tier $tier_num FAILED (exit code $exit_code) (${duration}s)"
        if $BAIL; then
            echo ""
            echo "Bailing out due to failure (--bail enabled)."
            print_summary
            exit 1
        fi
    fi
}

print_summary() {
    echo ""
    echo "========================================================================"
    echo " EXECUTION SUMMARY"
    echo "========================================================================"
    local total_pass=0
    local total_fail=0

    for i in "${!RESULTS[@]}"; do
        local name="${STATUS_NAMES[$i]}"
        local res="${RESULTS[$i]}"
        local dur="${DURATIONS[$i]}"

        if [[ "$res" == "PASS" ]]; then
            printf " [ PASS ]  %-50s (%s)\n" "$name" "$dur"
            ((total_pass++))
        else
            printf " [ FAIL ]  %-50s (%s)\n" "$name" "$dur"
            ((total_fail++))
        fi
    done

    echo "------------------------------------------------------------------------"
    echo " Total: ${#RESULTS[@]} | Passed: $total_pass | Failed: $total_fail"
    echo "========================================================================"

    if [[ ${#RESULTS[@]} -eq 0 || $total_pass -eq 0 ]]; then
        echo "ERROR: No test tiers were executed." >&2
        return 1
    elif [[ $total_pass -gt 0 && $total_fail -eq 0 ]]; then
        echo "ALL TIERS PASSED."
        return 0
    else
        echo "VALIDATION SUITE FAILED ($total_fail failure(s))."
        return 1
    fi
}

run_tier 1 "Static QML Syntax & Module Imports" "$T1_SCRIPT"
run_tier 2 "Schema Parity & Save Roundtrip" "$T2_SCRIPT"
run_tier 3 "Headless Wayland Runtime & Dynamic Mutation" "$T3_SCRIPT"
run_tier 4 "Requirement Acceptance Suite (R1-R4)" "$T4_SCRIPT"

print_summary
exit $?
