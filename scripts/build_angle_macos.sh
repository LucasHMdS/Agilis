#!/usr/bin/env bash
set -euo pipefail

# Build ANGLE from source for macOS (arm64 or x86_64)
# Prerequisites: Git, Python 3, Xcode Command Line Tools
# Output: libEGL.dylib, libGLESv2.dylib

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANGLE_BUILD_DIR="$SCRIPT_DIR/../build/angle"
ANGLE_OUTPUT_DIR="$SCRIPT_DIR/../Sources/AngleC/lib/macos"

# Detect host CPU for default target
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
    TARGET_CPU="arm64"
else
    TARGET_CPU="x64"
fi

# Step 1: Get depot_tools
echo "=== Step 1: Setting up depot_tools ==="
if [ ! -d "$ANGLE_BUILD_DIR/depot_tools" ]; then
    mkdir -p "$ANGLE_BUILD_DIR"
    cd "$ANGLE_BUILD_DIR"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
else
    echo "depot_tools already exists, updating..."
    cd "$ANGLE_BUILD_DIR/depot_tools"
    git pull
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
mkdir -p out/Release

cat > out/Release/args.gn << EOF
is_debug = false
angle_enable_metal = true
angle_enable_vulkan = false
angle_enable_gl = false
angle_enable_gl_desktop_backend = false
angle_enable_null = false
angle_build_tests = false
angle_build_samples = false
is_component_build = true
target_cpu = "$TARGET_CPU"
EOF

gn gen out/Release

# Step 4: Build
echo "=== Step 4: Building ANGLE ==="
ninja -C out/Release libEGL libGLESv2

# Step 5: Copy outputs
echo "=== Step 5: Copying binaries ==="
mkdir -p "$ANGLE_OUTPUT_DIR"

cp -f out/Release/libEGL.dylib "$ANGLE_OUTPUT_DIR/"
cp -f out/Release/libGLESv2.dylib "$ANGLE_OUTPUT_DIR/"

echo "=== Done! ==="
echo "ANGLE binaries copied to: $ANGLE_OUTPUT_DIR"
ls -la "$ANGLE_OUTPUT_DIR"
