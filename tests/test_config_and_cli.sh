#!/usr/bin/env bash
# Unit tests for Configuration Loading and CLI Flag Parsing
set -euo pipefail

describe "Config and CLI Flag Parsing"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/swap-memory.sh"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

test_default_values() {
    local output
    output=$(bash "$SCRIPT_PATH" --config "/nonexistent/path.conf" --dump-config)
    assert_contains "SWAP_PATH=/swapfile" "$output" "Default path should be /swapfile"
    assert_contains "SWAP_SIZE=8" "$output" "Default size should be 8"
    assert_contains "ACTION=start" "$output" "Default action should be start"
}
it "uses default values (/swapfile, 8GB, action=start) when no config or flags are given" test_default_values

test_custom_config() {
    local conf_file="$TEMP_DIR/custom.conf"
    cat << 'EOF' > "$conf_file"
SWAP_PATH="/opt/custom-swap"
SWAP_SIZE=4
EOF
    local output
    output=$(bash "$SCRIPT_PATH" -c "$conf_file" --dump-config)
    assert_contains "SWAP_PATH=/opt/custom-swap" "$output" "Should read path from config"
    assert_contains "SWAP_SIZE=4" "$output" "Should read size from config"
}
it "loads values from custom config file" test_custom_config

test_cli_overrides_config() {
    local conf_file="$TEMP_DIR/override.conf"
    cat << 'EOF' > "$conf_file"
SWAP_PATH="/conf/path"
SWAP_SIZE=2
EOF
    local output
    output=$(bash "$SCRIPT_PATH" -c "$conf_file" -p "/cli/path" -s 12 --dump-config)
    assert_contains "SWAP_PATH=/cli/path" "$output" "CLI -p flag should override config file"
    assert_contains "SWAP_SIZE=12" "$output" "CLI -s flag should override config file"
}
it "CLI flags override config file values" test_cli_overrides_config

test_positional_arguments() {
    local output
    output=$(bash "$SCRIPT_PATH" --config "/nonexistent" 16 /custom/pos/path --dump-config)
    assert_contains "SWAP_SIZE=16" "$output" "First positional argument should set size"
    assert_contains "SWAP_PATH=/custom/pos/path" "$output" "Second positional argument should set path"
}
it "supports positional arguments for backward compatibility (e.g. swap-memory.sh 16 /path)" test_positional_arguments

test_single_positional_arg() {
    local output
    output=$(bash "$SCRIPT_PATH" --config "/nonexistent" 4 --dump-config)
    assert_contains "SWAP_SIZE=4" "$output" "Single positional argument should set size"
    assert_contains "SWAP_PATH=/swapfile" "$output" "Path should remain default"
}
it "supports single positional argument for size only (e.g. swap-memory.sh 4)" test_single_positional_arg

test_stop_flag() {
    local output
    output=$(bash "$SCRIPT_PATH" --config "/nonexistent" --stop --dump-config)
    assert_contains "ACTION=stop" "$output" "Should set action to stop"
}
it "sets ACTION=stop when --stop flag is provided" test_stop_flag

test_help_flag() {
    local output
    output=$(bash "$SCRIPT_PATH" --help)
    assert_contains "Usage:" "$output" "Help output should contain Usage"
    assert_contains "--path" "$output" "Help output should mention --path"
    assert_contains "--size" "$output" "Help output should mention --size"
}
it "shows help message with --help and exits with 0" test_help_flag
