#!/usr/bin/env bash
set -euo pipefail

# Build ANGLE from source for iOS (arm64)
# Prerequisites: Git, Python 3, Xcode Command Line Tools
# Output: libEGL.framework, libGLESv2.framework
#
# Usage:
#   ./build_angle_ios.sh              # Build for device (default)
#   ./build_angle_ios.sh simulator    # Build for simulator
#   ./build_angle_ios.sh device       # Build for device (explicit)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANGLE_BUILD_DIR="$SCRIPT_DIR/../.build/angle"
ANGLE_OUTPUT_DIR="$SCRIPT_DIR/../Sources/AngleC/lib/ios"

TARGET_CPU="arm64"
TARGET_ENV="${1:-device}"

if [[ "$TARGET_ENV" != "device" && "$TARGET_ENV" != "simulator" ]]; then
    echo "Usage: $0 [device|simulator]"
    exit 1
fi

BUILD_SUBDIR="Release-ios-${TARGET_ENV}"

# Step 1: Get depot_tools
echo "=== Step 1: Setting up depot_tools ==="
if [ ! -d "$ANGLE_BUILD_DIR/depot_tools" ]; then
    mkdir -p "$ANGLE_BUILD_DIR"
    cd "$ANGLE_BUILD_DIR"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
else
    echo "depot_tools already exists, updating..."
    cd "$ANGLE_BUILD_DIR/depot_tools"
    git fetch origin
    git checkout -f origin/main
fi

export PATH="$ANGLE_BUILD_DIR/depot_tools:$PATH"

# Step 2: Fetch ANGLE source
echo "=== Step 2: Fetching ANGLE source ==="
if [ ! -d "$ANGLE_BUILD_DIR/angle" ]; then
    mkdir -p "$ANGLE_BUILD_DIR/angle"
    cd "$ANGLE_BUILD_DIR/angle"
    fetch angle
else
    echo "ANGLE source already exists, syncing..."
    cd "$ANGLE_BUILD_DIR/angle"
    gclient sync
fi

# Step 3: Generate build files
echo "=== Step 3: Generating build files ==="
cd "$ANGLE_BUILD_DIR/angle"
mkdir -p "out/$BUILD_SUBDIR"

GN_ARGS="is_debug = false
target_os = \"ios\"
target_cpu = \"$TARGET_CPU\"
target_environment = \"$TARGET_ENV\"
ios_deployment_target = \"14.0\"
angle_enable_metal = true
angle_enable_vulkan = false
angle_enable_gl = false
angle_enable_gl_desktop_backend = false
angle_enable_null = false
angle_build_tests = false
angle_build_samples = false
is_component_build = false"

if [ "$TARGET_ENV" = "device" ]; then
    GN_ARGS="$GN_ARGS
ios_enable_code_signing = false"
fi

echo "$GN_ARGS" > "out/$BUILD_SUBDIR/args.gn"

gn gen "out/$BUILD_SUBDIR"

# Step 4: Build
echo "=== Step 4: Building ANGLE for iOS ($TARGET_ENV) ==="
ninja -C "out/$BUILD_SUBDIR" libEGL libGLESv2

# Step 5: Copy outputs (iOS builds produce .framework bundles)
echo "=== Step 5: Copying frameworks ==="
mkdir -p "$ANGLE_OUTPUT_DIR"

# Copy frameworks
rm -rf "$ANGLE_OUTPUT_DIR/libEGL.framework" "$ANGLE_OUTPUT_DIR/libGLESv2.framework"
cp -R "out/$BUILD_SUBDIR/libEGL.framework" "$ANGLE_OUTPUT_DIR/"
cp -R "out/$BUILD_SUBDIR/libGLESv2.framework" "$ANGLE_OUTPUT_DIR/"

echo "=== Done! ==="
echo "ANGLE iOS ($TARGET_ENV) frameworks copied to: $ANGLE_OUTPUT_DIR"
ls -la "$ANGLE_OUTPUT_DIR"
