@echo off
REM Build ANGLE from source for Windows (x64)
REM Prerequisites: Git, Python 3, VS 2022 Build Tools
REM Output: libEGL.dll, libGLESv2.dll, libEGL.dll.lib, libGLESv2.dll.lib

setlocal enabledelayedexpansion

set "ANGLE_BUILD_DIR=%~dp0..\build\angle"
set "ANGLE_OUTPUT_DIR=%~dp0..\Sources\AngleC\lib\windows"

REM Step 1: Get depot_tools
echo === Step 1: Setting up depot_tools ===
if not exist "%ANGLE_BUILD_DIR%\depot_tools" (
    mkdir "%ANGLE_BUILD_DIR%" 2>nul
    cd /d "%ANGLE_BUILD_DIR%"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
) else (
    echo depot_tools already exists, updating...
    cd /d "%ANGLE_BUILD_DIR%\depot_tools"
    git pull
)

REM Add depot_tools to PATH (must be before other Python)
set "PATH=%ANGLE_BUILD_DIR%\depot_tools;%PATH%"
set "DEPOT_TOOLS_WIN_TOOLCHAIN=0"

REM Step 2: Fetch ANGLE source
echo === Step 2: Fetching ANGLE source ===
if not exist "%ANGLE_BUILD_DIR%\angle" (
    mkdir "%ANGLE_BUILD_DIR%\angle" 2>nul
    cd /d "%ANGLE_BUILD_DIR%\angle"
    fetch angle
) else (
    echo ANGLE source already exists, syncing...
    cd /d "%ANGLE_BUILD_DIR%\angle"
    gclient sync
)

REM Step 3: Generate build files
echo === Step 3: Generating build files ===
cd /d "%ANGLE_BUILD_DIR%\angle"

REM Create args.gn for Release build
mkdir out\Release 2>nul
(
echo is_debug = false
echo angle_enable_vulkan = true
echo angle_enable_d3d11 = true
echo angle_enable_d3d9 = false
echo angle_enable_gl = false
echo angle_enable_null = false
echo angle_build_tests = false
echo angle_build_samples = false
echo is_component_build = true
echo target_cpu = "x64"
) > out\Release\args.gn

gn gen out\Release

REM Step 4: Build
echo === Step 4: Building ANGLE ===
ninja -C out\Release libEGL libGLESv2

REM Step 5: Copy outputs
echo === Step 5: Copying binaries ===
mkdir "%ANGLE_OUTPUT_DIR%" 2>nul

copy /Y out\Release\libEGL.dll "%ANGLE_OUTPUT_DIR%\"
copy /Y out\Release\libGLESv2.dll "%ANGLE_OUTPUT_DIR%\"
copy /Y out\Release\libEGL.dll.lib "%ANGLE_OUTPUT_DIR%\"
copy /Y out\Release\libGLESv2.dll.lib "%ANGLE_OUTPUT_DIR%\"

REM Also copy d3dcompiler if present (needed at runtime)
if exist out\Release\d3dcompiler_47.dll (
    copy /Y out\Release\d3dcompiler_47.dll "%ANGLE_OUTPUT_DIR%\"
)

echo === Done! ===
echo ANGLE binaries copied to: %ANGLE_OUTPUT_DIR%
dir "%ANGLE_OUTPUT_DIR%"

endlocal
