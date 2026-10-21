#!/usr/bin/env bash
# Lightweight Bash Test Harness for linux-swap-memory-service
set -euo pipefail

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
CURRENT_SUITE=""
CURRENT_TEST=""

# ANSI Colors
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"

describe() {
    CURRENT_SUITE="$1"
    echo -e "\n${COLOR_CYAN}=== Suite: ${CURRENT_SUITE} ===${COLOR_RESET}"
}

it() {
    CURRENT_TEST="$1"
    shift
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Run the test in a subshell so failures don't abort the entire runner
    local output
    local status=0
    if output=$(set -euo pipefail; "$@" 2>&1); then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "  ${COLOR_GREEN}✔${COLOR_RESET} ${CURRENT_TEST}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "  ${COLOR_RED}✘${COLOR_RESET} ${CURRENT_TEST}"
        if [[ -n "$output" ]]; then
            echo -e "    ${COLOR_YELLOW}${output}${COLOR_RESET}"
        fi
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Assertion failed}"

    if [[ "$expected" != "$actual" ]]; then
        echo "ASSERTION FAILED: $msg"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
    return 0
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local msg="${3:-Expected string to contain needle}"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "ASSERTION FAILED: $msg"
        echo "  Needle:   '$needle'"
        echo "  Haystack: '$haystack'"
        return 1
    fi
    return 0
}

assert_file_exists() {
    local path="$1"
    local msg="${2:-Expected file '$path' to exist}"

    if [[ ! -e "$path" ]]; then
        echo "ASSERTION FAILED: $msg"
        return 1
    fi
    return 0
}

assert_dir_exists() {
    local path="$1"
    local msg="${2:-Expected directory '$path' to exist}"

    if [[ ! -d "$path" ]]; then
        echo "ASSERTION FAILED: $msg"
        return 1
    fi
    return 0
}

assert_success() {
    local msg="Expected command to succeed"
    if ! "$@"; then
        echo "ASSERTION FAILED: $msg (Command: '$*')"
        return 1
    fi
    return 0
}

assert_failure() {
    local msg="Expected command to fail"
    if "$@" >/dev/null 2>&1; then
        echo "ASSERTION FAILED: $msg (Command: '$*')"
        return 1
    fi
    return 0
}

# Export functions for use in test files
export -f describe it assert_equals assert_contains assert_file_exists assert_dir_exists assert_success assert_failure

# Main execution logic if invoked directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    TEST_FILES=("$@")

    if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        while IFS= read -r -d '' file; do
            TEST_FILES+=("$file")
        done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "test_*.sh" ! -name "test_runner.sh" -print0 | sort -z)
    fi

    if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
        echo "No test files found."
        exit 0
    fi

    for test_file in "${TEST_FILES[@]}"; do
        # shellcheck source=/dev/null
        source "$test_file"
    done

    echo -e "\n----------------------------------------"
    echo -e "Total: ${TOTAL_TESTS} | ${COLOR_GREEN}Passed: ${PASSED_TESTS}${COLOR_RESET} | ${COLOR_RED}Failed: ${FAILED_TESTS}${COLOR_RESET}"
    echo -e "----------------------------------------"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    fi
    exit 0
fi
