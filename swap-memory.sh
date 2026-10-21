#!/usr/bin/env bash
# linux-swap-memory-service
# Script for managing Linux swapfile path and size
set -euo pipefail

DEFAULT_CONF="/etc/swap-memory.conf"
SWAP_PATH="/swapfile"
SWAP_SIZE=8
ACTION="start"
CONFIG_FILE="$DEFAULT_CONF"
DUMP_CONFIG=0
VALIDATE_ONLY=0

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SIZE] [PATH]

Options:
  -c, --config <file>   ระบุไฟล์ configuration (default: /etc/swap-memory.conf)
  -p, --path <path>     ระบุตำแหน่ง swapfile (default: /swapfile)
  -s, --size <size_gb>  ระบุขนาด swapfile หน่วยเป็น GB (default: 8)
  --stop                สั่งปิดการใช้งาน swapfile ที่ระบุ
  --dump-config         แสดงค่าคอนฟิกปัจจุบัน (สำหรับทดสอบ)
  --validate-only       ตรวจสอบความถูกต้องของ path และสร้างโฟลเดอร์แม่ (สำหรับทดสอบ)
  -h, --help            แสดงข้อความช่วยเหลือนี้

Arguments (Backward Compatibility):
  SIZE                  ขนาด swapfile หน่วยเป็น GB (argument แรก)
  PATH                  ตำแหน่ง swapfile (argument ที่สอง)

Examples:
  $(basename "$0") -p /mnt/data/swapfile -s 16
  $(basename "$0") 16 /mnt/data/swapfile
  $(basename "$0") --stop
EOF
}

run_cmd() {
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1 && [[ -z "${NO_SUDO:-}" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

validate_swap_path() {
    local target_path="$1"
    local parent_dir
    parent_dir="$(dirname "$target_path")"

    if [[ -d "$target_path" ]]; then
        echo "[ERROR] Path ปลายทาง ($target_path) เป็น directory ต้องระบุเป็นชื่อไฟล์" >&2
        return 1
    fi

    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
        chmod 700 "$parent_dir"
    fi

    if [[ ! -w "$parent_dir" ]]; then
        echo "[ERROR] ไม่สามารถเขียนข้อมูลลงในโฟลเดอร์ $parent_dir ได้ (Permission denied)" >&2
        return 1
    fi
    return 0
}

is_swap_active() {
    local target_path="$1"
    if [[ -r /proc/swaps ]]; then
        grep -q "^${target_path}[[:space:]]" /proc/swaps 2>/dev/null && return 0
    fi
    return 1
}

show_swap_summary() {
    if [[ -r /proc/meminfo ]]; then
        grep -E "SwapTotal|SwapFree" /proc/meminfo || true
    fi
}

allocate_swapfile() {
    local target_path="$1"
    local size_gb="$2"
    echo "Allocating ${size_gb}GB swapfile at $target_path..."
    if ! run_cmd fallocate -l "${size_gb}G" "$target_path" 2>/dev/null; then
        echo "fallocate failed, falling back to dd..."
        local count_mb=$((size_gb * 1024))
        run_cmd dd if=/dev/zero of="$target_path" bs=1M count="$count_mb" status=none
    fi
    run_cmd chmod 0600 "$target_path"
}

start_swap() {
    local target_path="$1"
    local size_gb="$2"
    local expected_bytes=$((size_gb * 1024 * 1024 * 1024))

    validate_swap_path "$target_path"

    if [[ -f "$target_path" ]]; then
        local current_bytes
        current_bytes=$(stat -c "%s" "$target_path" 2>/dev/null || stat -f "%z" "$target_path" 2>/dev/null || echo 0)

        if [[ "$current_bytes" -eq "$expected_bytes" ]]; then
            echo "Existing swapfile found with matching size (${size_gb}GB)."
            run_cmd chmod 0600 "$target_path"
            if is_swap_active "$target_path"; then
                echo "Swapfile is already active."
            else
                echo "Activating existing swapfile..."
                run_cmd swapon "$target_path"
            fi
            show_swap_summary
            return 0
        fi

        echo "Existing swapfile size (${current_bytes} bytes) does not match expected (${expected_bytes} bytes). Recreating..."
        run_cmd swapoff "$target_path" 2>/dev/null || true
    fi

    allocate_swapfile "$target_path" "$size_gb"
    echo "Formatting swapfile with mkswap..."
    run_cmd mkswap "$target_path"
    echo "Activating swapfile with swapon..."
    run_cmd swapon "$target_path"
    show_swap_summary
}

stop_swap() {
    local target_path="$1"
    echo "Deactivating swap on $target_path..."
    run_cmd swapoff "$target_path" 2>/dev/null || true
    echo "Swap on $target_path stopped."
}

# Pass 1: ค้นหาไฟล์ config ก่อนเพื่อโหลดค่า
cli_args=("$@")
idx=0
while [[ $idx -lt ${#cli_args[@]} ]]; do
    case "${cli_args[$idx]}" in
        -c|--config)
            idx=$((idx + 1))
            if [[ $idx -lt ${#cli_args[@]} ]]; then
                CONFIG_FILE="${cli_args[$idx]}"
            fi
            ;;
    esac
    idx=$((idx + 1))
done

# โหลดค่าจากไฟล์ config ถ้ามีอยู่
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Pass 2: อ่าน flags และ arguments เพื่อ override ค่าจาก config
positional_args=()
idx=0
while [[ $idx -lt ${#cli_args[@]} ]]; do
    case "${cli_args[$idx]}" in
        -c|--config)
            idx=$((idx + 1)) # ข้าม value
            ;;
        -p|--path)
            idx=$((idx + 1))
            if [[ $idx -lt ${#cli_args[@]} ]]; then
                SWAP_PATH="${cli_args[$idx]}"
            fi
            ;;
        -s|--size)
            idx=$((idx + 1))
            if [[ $idx -lt ${#cli_args[@]} ]]; then
                SWAP_SIZE="${cli_args[$idx]}"
            fi
            ;;
        --stop)
            ACTION="stop"
            ;;
        --dump-config)
            DUMP_CONFIG=1
            ;;
        --validate-only)
            VALIDATE_ONLY=1
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: ${cli_args[$idx]}" >&2
            show_help
            exit 1
            ;;
        *)
            positional_args+=("${cli_args[$idx]}")
            ;;
    esac
    idx=$((idx + 1))
done

# จัดการ positional arguments
if [[ ${#positional_args[@]} -ge 1 ]]; then
    if [[ "${positional_args[0]}" =~ ^[0-9]+$ ]]; then
        SWAP_SIZE="${positional_args[0]}"
    fi
fi
if [[ ${#positional_args[@]} -ge 2 ]]; then
    SWAP_PATH="${positional_args[1]}"
fi

if [[ $DUMP_CONFIG -eq 1 ]]; then
    echo "SWAP_PATH=$SWAP_PATH"
    echo "SWAP_SIZE=$SWAP_SIZE"
    echo "ACTION=$ACTION"
    exit 0
fi

if [[ $VALIDATE_ONLY -eq 1 ]]; then
    validate_swap_path "$SWAP_PATH"
    exit $?
fi

# Main action execution
if [[ "$ACTION" == "stop" ]]; then
    stop_swap "$SWAP_PATH"
else
    start_swap "$SWAP_PATH" "$SWAP_SIZE"
fi