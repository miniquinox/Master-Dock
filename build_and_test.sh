#!/bin/bash
set -e

BUILD_DIR=".build"
CACHE_DIR="${BUILD_DIR}/cache"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"

mkdir -p "${BUILD_DIR}/bin"
mkdir -p "${CACHE_DIR}"

echo "=================================================="
echo "      BUILDING MASTER DOCK MACOS APPLICATION      "
echo "=================================================="

# 1. Compile C Multitouch Bridge
echo "[1/4] Compiling MasterDockMultitouchC..."
clang -c "Sources/MasterDockMultitouchC/MultitouchSupportBridge.c" \
    -I "Sources/MasterDockMultitouchC/include" \
    -isysroot "${SDK_PATH}" \
    -fmodules-cache-path="${CACHE_DIR}" \
    -o "${BUILD_DIR}/MultitouchSupportBridge.o"

# 2. Collect Swift Source Files via Array
echo "[2/4] Compiling MasterDock Swift Sources..."
SWIFT_SOURCES=()
while IFS= read -r -d '' file; do
    SWIFT_SOURCES+=("$file")
done < <(find Sources -name "*.swift" -print0)

swiftc -emit-executable \
    -sdk "${SDK_PATH}" \
    -module-cache-path "${CACHE_DIR}" \
    -Xcc -fmodules-cache-path="${CACHE_DIR}" \
    -I "Sources/MasterDockMultitouchC/include" \
    "${BUILD_DIR}/MultitouchSupportBridge.o" \
    "${SWIFT_SOURCES[@]}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework EventKit \
    -framework AVFoundation \
    -framework Speech \
    -framework Carbon \
    -framework Foundation \
    -o "${BUILD_DIR}/bin/MasterDock"

echo "✅ Successfully built MasterDock executable at ${BUILD_DIR}/bin/MasterDock"

# 3. Compile Test Runner
echo "[3/4] Compiling MasterDock Test Suite..."
TEST_SOURCES=()
while IFS= read -r -d '' file; do
    TEST_SOURCES+=("$file")
done < <(find Tests -name "*.swift" -print0)

NON_APP_SOURCES=()
while IFS= read -r -d '' file; do
    if [[ "$file" != *"AppMain.swift"* && "$file" != *"AppDelegate.swift"* ]]; then
        NON_APP_SOURCES+=("$file")
    fi
done < <(find Sources -name "*.swift" -print0)

swiftc -emit-executable \
    -sdk "${SDK_PATH}" \
    -module-cache-path "${CACHE_DIR}" \
    -Xcc -fmodules-cache-path="${CACHE_DIR}" \
    -I "Sources/MasterDockMultitouchC/include" \
    "${BUILD_DIR}/MultitouchSupportBridge.o" \
    "${NON_APP_SOURCES[@]}" \
    "${TEST_SOURCES[@]}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework EventKit \
    -framework AVFoundation \
    -framework Speech \
    -framework Carbon \
    -framework Foundation \
    -o "${BUILD_DIR}/bin/MasterDockTests"

echo "✅ Successfully built MasterDockTests at ${BUILD_DIR}/bin/MasterDockTests"

# 4. Run Test Suite
echo "[4/4] Executing MasterDock Tests..."
"${BUILD_DIR}/bin/MasterDockTests"

echo ""
echo "🎉 ALL BUILD & TEST STAGES PASSED SUCCESSFULLY!"
