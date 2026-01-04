#!/bin/bash
set -e

pkill -f ScreenShader 2>/dev/null || true
./build/Build/Products/Debug/ScreenShader.app/Contents/MacOS/ScreenShader
