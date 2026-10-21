#!/usr/bin/env bash
# Unit tests for install.sh and uninstall.sh scripts
set -euo pipefail

describe "Install and Uninstall Scripts"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

test_install_script_logic() {
    local fake_etc="$TEMP_DIR/etc"
    local fake_bin="$TEMP_DIR/bin"
    local fake_systemd="$fake_etc/systemd/system"
    mkdir -p "$fake_systemd" "$fake_bin"

    # Run install with mock targets
    ETC_DIR="$fake_etc" BIN_DIR="$fake_bin" SYSTEMD_DIR="$fake_systemd" \
        SKIP_SYSTEMCTL=1 NO_SUDO=1 bash "$PROJECT_ROOT/install.sh"

    assert_file_exists "$fake_etc/swap-memory.conf" "swap-memory.conf should be copied to /etc"
    assert_file_exists "$fake_systemd/swap-memory.service" "swap-memory.service should be copied to /etc/systemd/system"
    assert_file_exists "$fake_bin/swap-memory.sh" "swap-memory.sh should be copied to /usr/local/bin"
}
it "install.sh copies config, service, and script to target locations" test_install_script_logic

test_uninstall_script_with_remove_swap() {
    local fake_etc="$TEMP_DIR/u_etc"
    local fake_bin="$TEMP_DIR/u_bin"
    local fake_systemd="$fake_etc/systemd/system"
    local fake_swap="$TEMP_DIR/my_swapfile"

    mkdir -p "$fake_systemd" "$fake_bin"
    touch "$fake_swap"
    touch "$fake_systemd/swap-memory.service"
    touch "$fake_bin/swap-memory.sh"

    cat << EOF > "$fake_etc/swap-memory.conf"
SWAP_PATH="$fake_swap"
SWAP_SIZE=2
EOF

    # Run uninstall with --remove-swap
    ETC_DIR="$fake_etc" BIN_DIR="$fake_bin" SYSTEMD_DIR="$fake_systemd" \
        SKIP_SYSTEMCTL=1 NO_SUDO=1 bash "$PROJECT_ROOT/uninstall.sh" --remove-swap

    if [[ -f "$fake_systemd/swap-memory.service" ]]; then
        echo "ASSERTION FAILED: swap-memory.service should be removed"
        return 1
    fi
    if [[ -f "$fake_bin/swap-memory.sh" ]]; then
        echo "ASSERTION FAILED: swap-memory.sh should be removed"
        return 1
    fi
    if [[ -f "$fake_etc/swap-memory.conf" ]]; then
        echo "ASSERTION FAILED: swap-memory.conf should be removed"
        return 1
    fi
    if [[ -f "$fake_swap" ]]; then
        echo "ASSERTION FAILED: swapfile should be removed when --remove-swap is given"
        return 1
    fi
}
it "uninstall.sh removes service, script, config, and swapfile when --remove-swap is used" test_uninstall_script_with_remove_swap

test_uninstall_script_retains_swap_on_no() {
    local fake_etc="$TEMP_DIR/r_etc"
    local fake_bin="$TEMP_DIR/r_bin"
    local fake_systemd="$fake_etc/systemd/system"
    local fake_swap="$TEMP_DIR/retain_swapfile"

    mkdir -p "$fake_systemd" "$fake_bin"
    touch "$fake_swap"
    touch "$fake_systemd/swap-memory.service"
    touch "$fake_bin/swap-memory.sh"

    cat << EOF > "$fake_etc/swap-memory.conf"
SWAP_PATH="$fake_swap"
SWAP_SIZE=2
EOF

    # Answer 'n' to prompt
    echo "n" | (ETC_DIR="$fake_etc" BIN_DIR="$fake_bin" SYSTEMD_DIR="$fake_systemd" \
        SKIP_SYSTEMCTL=1 NO_SUDO=1 bash "$PROJECT_ROOT/uninstall.sh")

    assert_file_exists "$fake_swap" "Swapfile should be retained when user declines removal"
}
it "uninstall.sh retains swapfile when user does not confirm removal" test_uninstall_script_retains_swap_on_no
