#!/usr/bin/env bash
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
#
# Build protobuf from source and install to a local directory.
#
# Usage:
#   cd .workspace/protobuf
#   bash ../../scripts/build-protobuf.sh [--build-type Release|Debug] [--install-dir <path>]
#
# Prerequisites:
#   - Run from MSVC Developer Command Prompt (vcvars64.bat)
#   - CMake >= 3.20
#   - Ninja
#
# Paths are derived relative to the protobuf source root ($PWD):
#   Source:  $PWD                                    (.workspace/protobuf)
#   Build:   $PWD/../build/protobuf-release          (.workspace/build/protobuf-release)
#   Install: $PWD/../local-protobuf                  (.workspace/local-protobuf)

set -euo pipefail

BUILD_TYPE="Release"
INSTALL_DIR=""  # derived below unless overridden by --install-dir

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-type)  BUILD_TYPE="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

SRC="$(pwd)"
PARENT="$(cd "$SRC/.." && pwd)"
BUILD="$PARENT/build/$(basename "$SRC")-$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')"
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$PARENT/local-protobuf"
fi

echo "=== Protobuf Build Script ==="
echo "Source:     $SRC"
echo "Build:      $BUILD"
echo "Install:    $INSTALL_DIR"
echo "Build type: $BUILD_TYPE"
echo ""

# Verify we are in the protobuf directory
if [ ! -f "$SRC/CMakeLists.txt" ]; then
    echo "ERROR: Run this script from the protobuf root directory."
    echo "       Expected to find: CMakeLists.txt under $SRC"
    exit 1
fi

# MSVC runtime: /MT for Release, /MTd for Debug
if [ "$BUILD_TYPE" = "Debug" ]; then
    MSVC_RUNTIME="MultiThreadedDebug"
else
    MSVC_RUNTIME="MultiThreaded"
fi

# Clean build dir
rm -rf "$BUILD"

# Configure
echo "=== Configuring ==="
cmake -S . -B "$BUILD" -G Ninja \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_EXAMPLES=OFF \
    -Dprotobuf_ABSL_PROVIDER=module \
    -DCMAKE_CXX_STANDARD=17 \
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=$MSVC_RUNTIME"

# Build
echo ""
echo "=== Building ==="
cmake --build "$BUILD" --config "$BUILD_TYPE" --parallel

# Install
echo ""
echo "=== Installing to $INSTALL_DIR ==="
rm -rf "$INSTALL_DIR"
cmake --install "$BUILD" --config "$BUILD_TYPE"

echo ""
echo "=== Done. protobuf installed to $INSTALL_DIR ==="
echo "Run: bash scripts/package-and-upload.sh --name protobuf --version protobuf-<version>-release --build-dir $BUILD --install-dir $INSTALL_DIR"
