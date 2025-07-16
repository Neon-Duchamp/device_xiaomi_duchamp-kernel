#!/bin/bash

set -e

# Helper functions
info()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# Usage check
if [ $# -ne 1 ]; then
    echo "Usage: $0 ROOT_DIR"
    exit 1
fi

ROOT_DIR="$1"
info "Using ROOT_DIR: $ROOT_DIR"

# Auto-detect kernel module output dirs
DIST_DIR=$(find "$ROOT_DIR" -type d -path "*mgk_64_k61_kernel_aarch64.user" | head -n1)
MTK_DIST_DIR=$(find "$ROOT_DIR" -type d -path "*mgk_64_k61.user" | head -n1)
CUSTOMER_MODULES_DIR=$(find "$ROOT_DIR" -type d -path "*mgk_64_k61_customer_modules_install.user" | head -n1)

# Strip binary auto-locate (supports symlinks)
STRIP_BIN=$(find "$ROOT_DIR/prebuilts/clang/host/linux-x86" -name llvm-strip -exec test -x {} \; -print | head -n 1)

if [ -z "$STRIP_BIN" ]; then
    STRIP_BIN=$(command -v llvm-strip || true)
fi

if [ -z "$STRIP_BIN" ]; then
    error "llvm-strip not found in toolchain or system"
    exit 1
fi

info "Using llvm-strip: $STRIP_BIN"

# Check for required directories
for dir in "$DIST_DIR" "$MTK_DIST_DIR" "$CUSTOMER_MODULES_DIR"; do
    if [ ! -d "$dir" ]; then
        error "Missing directory: $dir"
        exit 1
    fi
done

# Create target directories
for TARGET in system vendor vendor_ramdisk; do
    mkdir -p "$TARGET"
done

# Copy kernel image
info "Copying kernel & DTB..."
cp "$DIST_DIR/Image.lz4" ./ || error "Failed to copy Image.lz4"
mv -f Image.lz4 kernel || error "Failed to rename kernel image"
chmod -x kernel

# Copy .ko modules to all targets
for TARGET in system vendor vendor_ramdisk; do
    info "Copying GKI modules to $TARGET..."
    find "$DIST_DIR" -type f -name '*.ko' -exec cp -v {} "$TARGET/" \;
    cp -v "$CUSTOMER_MODULES_DIR"/*.ko "$TARGET/" || true
done

# Optional cleanup
info "Cleaning up extra files..."
git clean -f system/ vendor/ vendor_ramdisk/ >/dev/null 2>&1 || true

# Strip modules
info "Stripping debug symbols from .ko modules..."
find . -type f -name '*.ko' -exec "$STRIP_BIN" --strip-debug {} +

info "✅ Operation completed successfully."
