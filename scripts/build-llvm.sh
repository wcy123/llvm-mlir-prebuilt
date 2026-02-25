#!/usr/bin/env bash
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
#
# Build LLVM/MLIR/LLD from source and install to ../local.
#
# Usage:
#   cd /c/Develop/m/source/llvm-project
#   bash /c/Develop/m/llvm-mlir-prebuilt/scripts/build-llvm.sh
#
# Prerequisites:
#   - Run from MSVC Developer Command Prompt (vcvars64.bat)
#   - CMake >= 3.20
#   - Ninja
#
# Paths (relative to llvm-project source root):
#   Source:  /c/Develop/m/source/llvm-project
#   Build:   /c/Develop/m/build/llvm-project
#   Install: /c/Develop/m/local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLVM_SRC="$(pwd)"
LLVM_BUILD="/c/Develop/m/build/llvm-project"
LLVM_INSTALL="/c/Develop/m/local"

echo "=== LLVM Build Script ==="
echo "Source:  $LLVM_SRC"
echo "Build:   $LLVM_BUILD"
echo "Install: $LLVM_INSTALL"
echo ""

# Verify we are in the llvm-project directory
if [ ! -f "$LLVM_SRC/llvm/CMakeLists.txt" ]; then
    echo "ERROR: Run this script from the llvm-project root directory."
    echo "       Expected: /c/Develop/m/source/llvm-project"
    exit 1
fi

# Configure
echo "=== Configuring ==="
cmake -S llvm -B "$LLVM_BUILD" \
    -DLLVM_ENABLE_PROJECTS="mlir;lld;clang" \
    -DCMAKE_INSTALL_PREFIX="$LLVM_INSTALL" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_ENABLE_RTTI=OFF \
    -DLLVM_INSTALL_UTILS=ON \
    -DLLVM_INCLUDE_TESTS=ON \
    -DLLVM_ENABLE_ZLIB=OFF \
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded\$<\$<CONFIG:Debug>:Debug>"

# Build
echo ""
echo "=== Building (this takes several hours) ==="
cmake --build "$LLVM_BUILD" --config Debug

# Install
echo ""
echo "=== Installing to $LLVM_INSTALL ==="
cmake --install "$LLVM_BUILD" --config Debug

echo ""
echo "=== Done. LLVM installed to $LLVM_INSTALL ==="
echo "Run scripts/package-and-upload.sh to package and upload to GitHub Releases."
