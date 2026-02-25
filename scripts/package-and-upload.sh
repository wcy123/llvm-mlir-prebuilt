#!/usr/bin/env bash
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
#
# Package the installed LLVM/MLIR/LLD into zip files and upload to GitHub Releases.
#
# Usage:
#   bash scripts/package-and-upload.sh [--version <tag>] [--install-dir <path>] [--dry-run]
#
# Examples:
#   bash scripts/package-and-upload.sh --version llvm-22.0.0-debug
#   bash scripts/package-and-upload.sh --version llvm-22.0.0-debug --dry-run
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - 7z or zip available
#   - Enough disk space for zip files (~17GB for Debug build)

set -euo pipefail

# --- Defaults ---
INSTALL_DIR="/c/Develop/m/local"
VERSION=""
DRY_RUN=false
REPO="wcy123/llvm-mlir-prebuilt"
PART_SIZE_MB=1800  # Keep each zip under 2GB GitHub limit

# --- Arg parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)   VERSION="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=true; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "ERROR: --version is required. Example: --version llvm-22.0.0-debug"
    exit 1
fi

WORK_DIR="$(pwd)/llvm-pkg-$$"
mkdir -p "$WORK_DIR"
trap "rm -rf $WORK_DIR" EXIT

echo "=== Package and Upload ==="
echo "Install dir: $INSTALL_DIR"
echo "Version tag: $VERSION"
echo "Repo:        $REPO"
echo "Work dir:    $WORK_DIR"
echo "Dry run:     $DRY_RUN"
echo ""

# --- Helper: split-zip a directory into parts ---
split_zip() {
    local name="$1"       # e.g. "llvm-lld"
    local src_dir="$2"    # directory to zip
    local out_dir="$3"    # where to write zip files

    echo "--- Packaging $name from $src_dir ---"
    if [ ! -d "$src_dir" ]; then
        echo "WARNING: $src_dir does not exist, skipping."
        return
    fi

    local tmp_zip="$WORK_DIR/${name}-full.zip"
    local platform="windows-x64"

    # Create zip
    if command -v 7z &>/dev/null; then
        7z a -tzip -mx=1 "$tmp_zip" "$src_dir/*" -r > /dev/null
    else
        (cd "$src_dir" && zip -r -1 -q "$tmp_zip" .)
    fi

    local size_mb=$(du -m "$tmp_zip" | cut -f1)
    echo "  Full zip: ${size_mb}MB"

    if [ "$size_mb" -le "$PART_SIZE_MB" ]; then
        # Single file, no splitting needed
        local out="$out_dir/${name}-${VERSION}-${platform}.zip"
        mv "$tmp_zip" "$out"
        echo "  Output: $out"
    else
        # Split into parts using 7z or split
        echo "  Splitting into ${PART_SIZE_MB}MB parts..."
        local part=1
        if command -v 7z &>/dev/null; then
            7z a -tzip -mx=1 -v${PART_SIZE_MB}m \
               "$WORK_DIR/${name}-split.zip" "$src_dir/*" -r > /dev/null
            for f in "$WORK_DIR"/${name}-split.zip.*; do
                local out="$out_dir/${name}-${VERSION}-${platform}-part$(printf '%02d' $part).zip"
                mv "$f" "$out"
                echo "  Part $part: $out ($(du -m "$out" | cut -f1)MB)"
                ((part++))
            done
        else
            # Fallback: split the zip file by bytes
            split -b ${PART_SIZE_MB}m "$tmp_zip" \
                "$out_dir/${name}-${VERSION}-${platform}-part"
            for f in "$out_dir"/${name}-${VERSION}-${platform}-part*; do
                mv "$f" "${f}.zip"
                echo "  Part: ${f}.zip ($(du -m "${f}.zip" | cut -f1)MB)"
            done
            rm "$tmp_zip"
        fi
    fi
}

# --- Stage directories ---
LLVM_LLD_STAGE="$WORK_DIR/stage-llvm-lld"
MLIR_STAGE="$WORK_DIR/stage-mlir"
mkdir -p "$LLVM_LLD_STAGE" "$MLIR_STAGE"

echo "=== Staging files ==="

# LLVM + LLD: libs, headers, cmake, utilities
echo "Staging LLVM + LLD..."
for d in \
    lib/cmake/llvm \
    lib/cmake/lld \
    include/llvm \
    include/llvm-c \
    include/lld; do
    if [ -d "$INSTALL_DIR/$d" ]; then
        mkdir -p "$LLVM_LLD_STAGE/$d"
        cp -r "$INSTALL_DIR/$d/." "$LLVM_LLD_STAGE/$d/"
    fi
done

# LLVM static libs
mkdir -p "$LLVM_LLD_STAGE/lib"
find "$INSTALL_DIR/lib" -maxdepth 1 -name "LLVM*.lib" \
    -exec cp {} "$LLVM_LLD_STAGE/lib/" \;
# LLD static libs
find "$INSTALL_DIR/lib" -maxdepth 1 -name "lld*.lib" \
    -exec cp {} "$LLVM_LLD_STAGE/lib/" \;

# LLVM utilities needed for building (FileCheck, llvm-tblgen, lit, etc.)
mkdir -p "$LLVM_LLD_STAGE/bin"
for exe in \
    FileCheck llvm-tblgen llvm-lit llvm-as llvm-dis \
    llvm-link llvm-ar llvm-nm llvm-objdump llvm-config \
    count not split-file lld-link ld.lld clang clang++; do
    for f in "$INSTALL_DIR/bin/${exe}" "$INSTALL_DIR/bin/${exe}.exe"; do
        [ -f "$f" ] && cp "$f" "$LLVM_LLD_STAGE/bin/"
    done
done

# MLIR: libs, headers, cmake, tools
echo "Staging MLIR..."
for d in \
    lib/cmake/mlir \
    include/mlir \
    include/mlir-c; do
    if [ -d "$INSTALL_DIR/$d" ]; then
        mkdir -p "$MLIR_STAGE/$d"
        cp -r "$INSTALL_DIR/$d/." "$MLIR_STAGE/$d/"
    fi
done

# MLIR static libs
mkdir -p "$MLIR_STAGE/lib"
find "$INSTALL_DIR/lib" -maxdepth 1 -name "MLIR*.lib" \
    -exec cp {} "$MLIR_STAGE/lib/" \;

# MLIR tools
mkdir -p "$MLIR_STAGE/bin"
for exe in mlir-tblgen mlir-opt mlir-lsp-server; do
    for f in "$INSTALL_DIR/bin/${exe}" "$INSTALL_DIR/bin/${exe}.exe"; do
        [ -f "$f" ] && cp "$f" "$MLIR_STAGE/bin/"
    done
done

# --- Package ---
echo ""
echo "=== Creating zip files ==="
ZIP_OUT="$WORK_DIR/zips"
mkdir -p "$ZIP_OUT"

split_zip "llvm-lld" "$LLVM_LLD_STAGE" "$ZIP_OUT"
split_zip "mlir"     "$MLIR_STAGE"     "$ZIP_OUT"

echo ""
echo "=== Generated files ==="
ls -lh "$ZIP_OUT"

# --- Upload ---
if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "=== Dry run: skipping upload ==="
    echo "Would upload to: https://github.com/$REPO/releases/tag/$VERSION"
    exit 0
fi

echo ""
echo "=== Creating GitHub release $VERSION ==="
gh release create "$VERSION" \
    --repo "$REPO" \
    --title "LLVM/MLIR/LLD $VERSION" \
    --notes "Prebuilt LLVM+MLIR+LLD for Windows x64. See README for build config." \
    2>/dev/null || echo "Release $VERSION already exists, uploading to existing release."

echo ""
echo "=== Uploading zip files ==="
for f in "$ZIP_OUT"/*.zip; do
    echo "Uploading $(basename $f) ($(du -h "$f" | cut -f1))..."
    gh release upload "$VERSION" "$f" \
        --repo "$REPO" \
        --clobber
done

echo ""
echo "=== Done ==="
echo "Release: https://github.com/$REPO/releases/tag/$VERSION"
