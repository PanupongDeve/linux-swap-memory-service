#!/usr/bin/env bash
# Unit tests for Swap Lifecycle (Reuse, Recreate, Fallback Allocation, Isolated Stop)
set -euo pipefail

describe "Swap Lifecycle"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/swap-memory.sh"
TEMP_DIR="$(mktemp -d)"
MOCK_BIN="$TEMP_DIR/bin"
MOCK_LOG="$TEMP_DIR/mock_commands.log"

mkdir -p "$MOCK_BIN"

# Create mock commands that log invocations
create_mocks() {
    rm -f "$MOCK_LOG"
    cat << 'EOF' > "$MOCK_BIN/swapon"
#!/usr/bin/env bash
echo "swapon $*" >> "$MOCK_LOG"
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/swapoff"
#!/usr/bin/env bash
echo "swapoff $*" >> "$MOCK_LOG"
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/mkswap"
#!/usr/bin/env bash
echo "mkswap $*" >> "$MOCK_LOG"
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/fallocate"
#!/usr/bin/env bash
if [[ -n "${FORCE_FALLOCATE_FAIL:-}" ]]; then
    exit 1
fi
echo "fallocate $*" >> "$MOCK_LOG"
# Create dummy file if -l is specified
touch "${@: -1}"
exit 0
EOF
    cat << 'EOF' > "$MOCK_BIN/dd"
#!/usr/bin/env bash
echo "dd $*" >> "$MOCK_LOG"
for arg in "$@"; do
    if [[ "$arg" =~ ^of=(.+) ]]; then
        touch "${BASH_REMATCH[1]}"
    fi
done
exit 0
EOF
    chmod +x "$MOCK_BIN"/*
}

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

create_mocks

test_isolated_stop() {
    local target_swap="$TEMP_DIR/swapfile"
    touch "$target_swap"
    rm -f "$MOCK_LOG"

    PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" NO_SUDO=1 \
        bash "$SCRIPT_PATH" -p "$target_swap" --stop

    local log_content
    log_content=$(cat "$MOCK_LOG")
    assert_contains "swapoff $target_swap" "$log_content" "Should call swapoff on specific file"

    if [[ "$log_content" == *"swapoff -a"* ]]; then
        echo "ASSERTION FAILED: Should not call swapoff -a"
        return 1
    fi
}
it "isolated stop calls swapoff on specific path and never swapoff -a" test_isolated_stop

test_smart_reuse() {
    local target_swap="$TEMP_DIR/reuse_swap"
    # Create file with 1GB exact size (1073741824 bytes) using truncate
    truncate -s 1073741824 "$target_swap"
    rm -f "$MOCK_LOG"

    # Test with size 1GB (-s 1)
    PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" NO_SUDO=1 \
        bash "$SCRIPT_PATH" -p "$target_swap" -s 1

    local log_content=""
    if [[ -f "$MOCK_LOG" ]]; then
        log_content=$(cat "$MOCK_LOG")
    fi

    # Should swapon without mkswap because size matches
    assert_contains "swapon $target_swap" "$log_content" "Should call swapon for existing matching file"
    if [[ "$log_content" == *"mkswap"* ]]; then
        echo "ASSERTION FAILED: mkswap should not be called when file size matches"
        return 1
    fi
}
it "reuses existing swapfile when size matches without calling mkswap" test_smart_reuse

test_recreate_on_size_mismatch() {
    local target_swap="$TEMP_DIR/resize_swap"
    # Create file with 500MB (mismatched with requested 2GB)
    truncate -s 524288000 "$target_swap"
    rm -f "$MOCK_LOG"

    # Request 2GB (-s 2)
    PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" NO_SUDO=1 \
        bash "$SCRIPT_PATH" -p "$target_swap" -s 2

    local log_content
    log_content=$(cat "$MOCK_LOG")

    assert_contains "swapoff $target_swap" "$log_content" "Should swapoff existing file before resizing"
    assert_contains "fallocate -l 2G $target_swap" "$log_content" "Should allocate 2GB"
    assert_contains "mkswap $target_swap" "$log_content" "Should mkswap new file"
    assert_contains "swapon $target_swap" "$log_content" "Should swapon new file"
}
it "recreates and formats swapfile when existing size does not match" test_recreate_on_size_mismatch

test_fallback_to_dd() {
    local target_swap="$TEMP_DIR/dd_swap"
    rm -f "$MOCK_LOG"

    FORCE_FALLOCATE_FAIL=1 PATH="$MOCK_BIN:$PATH" MOCK_LOG="$MOCK_LOG" NO_SUDO=1 \
        bash "$SCRIPT_PATH" -p "$target_swap" -s 1

    local log_content
    log_content=$(cat "$MOCK_LOG")

    assert_contains "dd if=/dev/zero of=$target_swap" "$log_content" "Should fallback to dd when fallocate fails"
    assert_contains "mkswap $target_swap" "$log_content" "Should mkswap after dd"
    assert_contains "swapon $target_swap" "$log_content" "Should swapon after dd"
}
it "falls back to dd when fallocate fails" test_fallback_to_dd
