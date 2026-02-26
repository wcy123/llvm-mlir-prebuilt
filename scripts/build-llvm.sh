#!/usr/bin/env bash
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
#
# Build LLVM/MLIR/LLD from source and install to a local directory.
#
# Usage:
#   cd .workspace/llvm-project
#   bash ../../scripts/build-llvm.sh [--build-type Release|Debug] [--install-dir <path>]
#
# Prerequisites:
#   - Run from MSVC Developer Command Prompt (vcvars64.bat)
#   - CMake >= 3.20
#   - Ninja
#
# Paths are derived relative to the llvm-project source root ($PWD):
#   Source:  $PWD                                   (.workspace/llvm-project)
#   Build:   $PWD/../build/llvm-project-release      (.workspace/build/llvm-project-release)
#   Install: $PWD/../local                           (.workspace/local)

set -euo pipefail

BUILD_TYPE="Release"
LLVM_INSTALL=""  # derived below unless overridden by --install-dir

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-type)  BUILD_TYPE="$2"; shift 2 ;;
        --install-dir) LLVM_INSTALL="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

LLVM_SRC="$(pwd)"
LLVM_PARENT="$(cd "$LLVM_SRC/.." && pwd)"
LLVM_BUILD="$LLVM_PARENT/build/$(basename "$LLVM_SRC")-$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')"
if [ -z "$LLVM_INSTALL" ]; then
    LLVM_INSTALL="$LLVM_PARENT/local"
fi

echo "=== LLVM Build Script ==="
echo "Source:     $LLVM_SRC"
echo "Build:      $LLVM_BUILD"
echo "Install:    $LLVM_INSTALL"
echo "Build type: $BUILD_TYPE"
echo ""

# Verify we are in the llvm-project directory
if [ ! -f "$LLVM_SRC/llvm/CMakeLists.txt" ]; then
    echo "ERROR: Run this script from the llvm-project root directory."
    echo "       Expected to find: llvm/CMakeLists.txt under $LLVM_SRC"
    exit 1
fi

# Clean build dir
rm -rf "$LLVM_BUILD"

# MSVC runtime: /MT for Release, /MTd for Debug
if [ "$BUILD_TYPE" = "Debug" ]; then
    MSVC_RUNTIME="MultiThreadedDebug"
else
    MSVC_RUNTIME="MultiThreaded"
fi

# Configure
echo "=== Configuring ==="
cmake -S llvm -B "$LLVM_BUILD" -G Ninja \
    -DLLVM_ENABLE_PROJECTS="mlir;lld;clang" \
    -DCMAKE_INSTALL_PREFIX="$LLVM_INSTALL" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_ENABLE_RTTI=OFF \
    -DLLVM_INSTALL_UTILS=ON \
    -DLLVM_INCLUDE_TESTS=ON \
    -DLLVM_ENABLE_ZLIB=OFF \
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=$MSVC_RUNTIME"

# Build
echo ""
echo "=== Building ==="
cmake --build "$LLVM_BUILD" --config "$BUILD_TYPE" --parallel

# Install
echo ""
echo "=== Installing to $LLVM_INSTALL ==="
rm -rf "$LLVM_INSTALL"
cmake --install "$LLVM_BUILD" --config "$BUILD_TYPE"

echo ""
echo "=== Done. LLVM installed to $LLVM_INSTALL ==="
echo "Run: bash scripts/package-and-upload.sh --version llvm-<version>-release --install-dir $LLVM_INSTALL"
