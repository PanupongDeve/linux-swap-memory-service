#!/usr/bin/env bash
# Installation script for linux-swap-memory-service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  -p, --path <path>     กำหนดตำแหน่ง swapfile สำหรับ config เริ่มต้น
  -s, --size <size_gb>  กำหนดขนาด swapfile สำหรับ config เริ่มต้น
  -h, --help            แสดงข้อความช่วยเหลือนี้
EOF
}

CUSTOM_PATH=""
CUSTOM_SIZE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            shift
            CUSTOM_PATH="${1:-}"
            ;;
        -s|--size)
            shift
            CUSTOM_SIZE="${1:-}"
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

echo "=== Installing linux-swap-memory-service ==="

# 1. ติดตั้ง configuration file
run_cmd mkdir -p "$ETC_DIR"
CONF_TARGET="$ETC_DIR/swap-memory.conf"
if [[ ! -f "$CONF_TARGET" ]]; then
    echo "Creating configuration file at $CONF_TARGET..."
    run_cmd cp "$SCRIPT_DIR/swap-memory.conf" "$CONF_TARGET"
    run_cmd chmod 644 "$CONF_TARGET"
else
    echo "Existing configuration found at $CONF_TARGET (skipping overwrite)."
fi

# ปรับค่า config เริ่มต้นหากผู้ใช้ระบุผ่าน CLI flag
if [[ -n "$CUSTOM_PATH" ]]; then
    run_cmd sed -i "s|^SWAP_PATH=.*|SWAP_PATH=\"$CUSTOM_PATH\"|" "$CONF_TARGET"
fi
if [[ -n "$CUSTOM_SIZE" ]]; then
    run_cmd sed -i "s|^SWAP_SIZE=.*|SWAP_SIZE=$CUSTOM_SIZE|" "$CONF_TARGET"
fi

# 2. ติดตั้ง systemd service unit
run_cmd mkdir -p "$SYSTEMD_DIR"
echo "Installing service unit to $SYSTEMD_DIR/swap-memory.service..."
run_cmd cp "$SCRIPT_DIR/swap-memory.service" "$SYSTEMD_DIR/"
run_cmd chmod 644 "$SYSTEMD_DIR/swap-memory.service"

# 3. ติดตั้ง script ไปยัง bin directory
run_cmd mkdir -p "$BIN_DIR"
echo "Installing script to $BIN_DIR/swap-memory.sh..."
run_cmd cp "$SCRIPT_DIR/swap-memory.sh" "$BIN_DIR/"
run_cmd chmod 755 "$BIN_DIR/swap-memory.sh"

# 4. Reload และเปิดใช้งาน service
if [[ "$SKIP_SYSTEMCTL" -eq 0 ]] && command -v systemctl >/dev/null 2>&1; then
    echo "Reloading systemd daemon..."
    run_cmd systemctl daemon-reload

    echo "Enabling swap-memory.service..."
    run_cmd systemctl enable swap-memory.service

    echo "Starting swap-memory.service..."
    run_cmd systemctl start swap-memory.service

    echo "Service status:"
    run_cmd systemctl status swap-memory.service --no-pager || true
fi

echo "=== Installation completed successfully ==="