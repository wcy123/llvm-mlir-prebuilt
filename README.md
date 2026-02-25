<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->
# llvm-mlir-prebuilt

Prebuilt LLVM/MLIR/LLD binaries for Windows x64, built from source on a local
machine and distributed via GitHub Releases.

## Contents

Each release contains:
- `llvm-lld-<version>-windows-x64-part*.zip` — LLVM + LLD static libraries,
  headers, cmake config files (`LLVMConfig.cmake`, `LLDConfig.cmake`), and
  LLVM utilities (`FileCheck`, `llvm-tblgen`, `llvm-lit`, etc.)
- `mlir-<version>-windows-x64-part*.zip` — MLIR static libraries, headers,
  cmake config files (`MLIRConfig.cmake`), and MLIR tools (`mlir-tblgen`, etc.)

## Build Configuration

Built with:
- **LLVM version**: see release tag
- **Projects**: `mlir;lld;clang`
- **Targets**: `host` (x86_64)
- **Build type**: Debug
- **Compiler**: MSVC (`cl.exe`)
- **Runtime**: `/MTd` (`MultiThreaded$<$<CONFIG:Debug>:Debug>`)
- **RTTI**: OFF
- **Shared libs**: OFF (static only)
- **Assertions**: ON
- **Zlib**: OFF

## How to Consume in CMake

Extract all zip files to the same directory (e.g., `../local`), then:

```bash
cmake -DCMAKE_PREFIX_PATH=/path/to/local ...
```

CMake will find `LLVMConfig.cmake`, `MLIRConfig.cmake`, and `LLDConfig.cmake`
automatically.

## How to Download in CI

```yaml
- name: Download prebuilt LLVM/MLIR/LLD
  shell: bash
  run: |
    mkdir -p local
    gh release download <tag> \
      --repo wcy123/llvm-mlir-prebuilt \
      --pattern "*.zip" \
      --dir ./llvm-pkg
    for f in ./llvm-pkg/*.zip; do
      unzip -q "$f" -d ./local
    done
  env:
    GH_TOKEN: ${{ github.token }}
```

## How to Build and Publish a New Release

See `scripts/build-llvm.sh` for build instructions and
`scripts/package-and-upload.sh` to package and upload to GitHub Releases.
