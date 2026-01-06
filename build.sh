#!/bin/bash
set -e

xcodebuild -project ScreenShader.xcodeproj -scheme ScreenShader -configuration Debug \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

open ./build/Build/Products/Debug/ScreenShader.app
