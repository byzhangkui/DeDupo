#!/bin/bash
# Build the Rust core library for Xcode integration.
#
# This script is called as an Xcode Build Phase (Run Script),
# placed before the "Compile Sources" phase.

set -e
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

RUST_DIR="${SRCROOT}/dedupo-core"
cd "$RUST_DIR"

# Determine Rust target based on Xcode build architecture
if [ "$PLATFORM_NAME" = "macosx" ]; then
    if [ "$ARCHS" = "arm64" ]; then
        RUST_TARGET="aarch64-apple-darwin"
    else
        RUST_TARGET="x86_64-apple-darwin"
    fi
fi

# Default to host architecture for standalone builds
if [ -z "$RUST_TARGET" ]; then
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        RUST_TARGET="aarch64-apple-darwin"
    else
        RUST_TARGET="x86_64-apple-darwin"
    fi
fi

echo "Building dedupo-core for target: $RUST_TARGET"

# Build mode
if [ "$CONFIGURATION" = "Release" ]; then
    cargo build --release --target "$RUST_TARGET"
    LIB_PATH="target/$RUST_TARGET/release"
else
    cargo build --target "$RUST_TARGET"
    LIB_PATH="target/$RUST_TARGET/debug"
fi

# Copy static library to where Xcode can find it
if [ -n "$BUILT_PRODUCTS_DIR" ]; then
    cp "$LIB_PATH/libdedupo_core.a" "${BUILT_PRODUCTS_DIR}/"
    echo "Copied libdedupo_core.a to ${BUILT_PRODUCTS_DIR}/"
fi

# Generate C header file
cbindgen --config cbindgen.toml --crate dedupo-core \
    --output "${SRCROOT:-..}/DeDupo/Bridge/dedupo_ffi.h"

echo "Build complete."
