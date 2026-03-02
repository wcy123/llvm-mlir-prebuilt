#!/usr/bin/env bash
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
#
# Build abseil-cpp from source and install to a local directory.
#
# Usage:
#   cd .workspace/abseil-cpp
#   bash ../../scripts/build-absl.sh [--build-type Release|Debug] [--install-dir <path>]
#
# Prerequisites:
#   - Run from MSVC Developer Command Prompt (vcvars64.bat)
#   - CMake >= 3.20
#   - Ninja
#
# Paths are derived relative to the abseil-cpp source root ($PWD):
#   Source:  $PWD                                    (.workspace/abseil-cpp)
#   Build:   $PWD/../build/abseil-cpp-release        (.workspace/build/abseil-cpp-release)
#   Install: $PWD/../local-absl                      (.workspace/local-absl)

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
    INSTALL_DIR="$PARENT/local-absl"
fi

echo "=== abseil-cpp Build Script ==="
echo "Source:     $SRC"
echo "Build:      $BUILD"
echo "Install:    $INSTALL_DIR"
echo "Build type: $BUILD_TYPE"
echo ""

# Verify we are in the abseil-cpp directory
if [ ! -f "$SRC/CMakeLists.txt" ]; then
    echo "ERROR: Run this script from the abseil-cpp root directory."
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
    -DABSL_BUILD_TESTING=OFF \
    -DABSL_ENABLE_INSTALL=ON \
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
echo "=== Done. abseil-cpp installed to $INSTALL_DIR ==="
echo "Run: bash scripts/package-and-upload.sh --name absl --version absl-<version>-release --build-dir $BUILD --install-dir $INSTALL_DIR"
