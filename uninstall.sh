#!/usr/bin/env bash
# Uninstallation script for linux-swap-memory-service
set -euo pipefail

ETC_DIR="${ETC_DIR:-/etc}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
SKIP_SYSTEMCTL="${SKIP_SYSTEMCTL:-0}"

run_cmd() {
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1 && [[ -z "${NO_SUDO:-}" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes          ยืนยันการทำงานทั้งหมดโดยไม่ต้อง prompt ถาม
  --remove-swap      สั่งลบไฟล์ swapfile เพื่อคืนพื้นที่ดิสก์ทันที
  -h, --help         แสดงข้อความช่วยเหลือนี้
EOF
}

REMOVE_SWAP=0
FORCE_YES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            FORCE_YES=1
            ;;
        --remove-swap)
            REMOVE_SWAP=1
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
    shift
done

echo "=== Uninstalling linux-swap-memory-service ==="

# ค้นหา swap path จากไฟล์ config ก่อนทำการลบ
SWAP_PATH="/swapfile"
CONF_FILE="$ETC_DIR/swap-memory.conf"
if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
fi

# 1. หยุดและปิดการใช้งาน service
if [[ "$SKIP_SYSTEMCTL" -eq 0 ]] && command -v systemctl >/dev/null 2>&1; then
    echo "Stopping swap-memory.service..."
    run_cmd systemctl stop swap-memory.service 2>/dev/null || true

    echo "Disabling swap-memory.service..."
    run_cmd systemctl disable swap-memory.service 2>/dev/null || true
fi

# 2. ลบไฟล์ service unit และ script
echo "Removing service unit files..."
run_cmd rm -f "$SYSTEMD_DIR/swap-memory.service"
run_cmd rm -f "$SYSTEMD_DIR/default.target.wants/swap-memory.service"

echo "Removing script from $BIN_DIR/swap-memory.sh..."
run_cmd rm -f "$BIN_DIR/swap-memory.sh"

echo "Removing configuration from $CONF_FILE..."
run_cmd rm -f "$CONF_FILE"

if [[ "$SKIP_SYSTEMCTL" -eq 0 ]] && command -v systemctl >/dev/null 2>&1; then
    run_cmd systemctl daemon-reload 2>/dev/null || true
fi

# 3. จัดการไฟล์ swapfile
if [[ -f "$SWAP_PATH" ]]; then
    delete_file=0
    if [[ $REMOVE_SWAP -eq 1 || $FORCE_YES -eq 1 ]]; then
        delete_file=1
    else
        read -r -p "ต้องการลบไฟล์ swapfile ที่ $SWAP_PATH เพื่อคืนพื้นที่ดิสก์หรือไม่? [y/N]: " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            delete_file=1
        fi
    fi

    if [[ $delete_file -eq 1 ]]; then
        echo "Deactivating and removing swapfile at $SWAP_PATH..."
        run_cmd swapoff "$SWAP_PATH" 2>/dev/null || true
        run_cmd rm -f "$SWAP_PATH"
        echo "Removed swapfile at $SWAP_PATH."
    else
        echo "คงไฟล์ swapfile ไว้ที่ $SWAP_PATH เรียบร้อยแล้ว"
    fi
fi

echo "=== Uninstallation completed successfully ==="
