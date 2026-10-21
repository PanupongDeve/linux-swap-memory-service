#!/usr/bin/env bash
# Unit tests for Path and Parent Directory Validation
set -euo pipefail

describe "Path and Directory Validation"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/swap-memory.sh"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

test_auto_create_parent_dir() {
    local target_dir="$TEMP_DIR/nested/deep/swap"
    local target_file="$target_dir/test_swapfile"

    assert_success bash "$SCRIPT_PATH" -p "$target_file" --validate-only
    assert_dir_exists "$target_dir" "Parent directory should be automatically created"

    # Check permission of created parent dir (octal 700)
    local perm
    perm=$(stat -c "%a" "$target_dir")
    assert_equals "700" "$perm" "Parent directory permission should be 700"
}
it "automatically creates parent directory with 700 permissions" test_auto_create_parent_dir

test_reject_existing_directory() {
    local existing_dir="$TEMP_DIR/existing_dir"
    mkdir -p "$existing_dir"

    # Should fail because target path is a directory, not a file
    assert_failure bash "$SCRIPT_PATH" -p "$existing_dir" --validate-only
}
it "rejects when target path is an existing directory" test_reject_existing_directory

test_accept_valid_path_in_existing_dir() {
    local valid_file="$TEMP_DIR/swap.img"
    assert_success bash "$SCRIPT_PATH" -p "$valid_file" --validate-only
}
it "accepts valid file path in existing directory" test_accept_valid_path_in_existing_dir
