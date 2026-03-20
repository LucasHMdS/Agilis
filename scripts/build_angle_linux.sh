#!/usr/bin/env bash
set -euo pipefail

# Build ANGLE from source for Linux (x64)
# Prerequisites: Git, Python 3, clang/gcc, pkg-config, libx11-dev, libxext-dev
# Output: libEGL.so, libGLESv2.so

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANGLE_BUILD_DIR="$SCRIPT_DIR/../.build/angle"
ANGLE_OUTPUT_DIR="$SCRIPT_DIR/../Sources/AngleC/lib/linux"

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
mkdir -p out/Release

cat > out/Release/args.gn << 'EOF'
is_debug = false
angle_enable_vulkan = true
angle_enable_gl = true
angle_enable_null = false
angle_build_tests = false
angle_build_samples = false
is_component_build = true
target_cpu = "x64"
EOF

gn gen out/Release

# Step 4: Build
echo "=== Step 4: Building ANGLE ==="
ninja -C out/Release libEGL libGLESv2

# Step 5: Copy outputs
echo "=== Step 5: Copying binaries ==="
mkdir -p "$ANGLE_OUTPUT_DIR"

cp -f out/Release/libEGL.so "$ANGLE_OUTPUT_DIR/"
cp -f out/Release/libGLESv2.so "$ANGLE_OUTPUT_DIR/"

echo "=== Done! ==="
echo "ANGLE binaries copied to: $ANGLE_OUTPUT_DIR"
ls -la "$ANGLE_OUTPUT_DIR"
