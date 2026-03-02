#!/usr/bin/env bash
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
#
# Build FlatBuffers from source and install to a local directory.
#
# Usage:
#   cd .workspace/flatbuffers
#   bash ../../scripts/build-flatbuffers.sh [--build-type Release|Debug] [--install-dir <path>]
#
# Prerequisites:
#   - Run from MSVC Developer Command Prompt (vcvars64.bat)
#   - CMake >= 3.20
#   - Ninja
#
# Paths are derived relative to the flatbuffers source root ($PWD):
#   Source:  $PWD                                       (.workspace/flatbuffers)
#   Build:   $PWD/../build/flatbuffers-release          (.workspace/build/flatbuffers-release)
#   Install: $PWD/../local-flatbuffers                  (.workspace/local-flatbuffers)

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
    INSTALL_DIR="$PARENT/local-flatbuffers"
fi

echo "=== FlatBuffers Build Script ==="
echo "Source:     $SRC"
echo "Build:      $BUILD"
echo "Install:    $INSTALL_DIR"
echo "Build type: $BUILD_TYPE"
echo ""

# Verify we are in the flatbuffers directory
if [ ! -f "$SRC/CMakeLists.txt" ]; then
    echo "ERROR: Run this script from the flatbuffers root directory."
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
    -DFLATBUFFERS_BUILD_TESTS=OFF \
    -DFLATBUFFERS_BUILD_BENCHMARKS=OFF \
    -DFLATBUFFERS_INSTALL=ON \
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
echo "=== Done. FlatBuffers installed to $INSTALL_DIR ==="
echo "Run: bash scripts/package-and-upload.sh --name flatbuffers --version flatbuffers-<version>-release --build-dir $BUILD --install-dir $INSTALL_DIR"
