#!/bin/bash
# Used by the GitHub build (see .github/workflows/release.yml). You don't need to run this yourself.
set -e
cd "$(dirname "$0")"
swift build -c release
BIN=$(swift build -c release --show-bin-path)/Islet
rm -rf build && mkdir -p build/Islet.app/Contents/MacOS build/dmg
cp "$BIN" build/Islet.app/Contents/MacOS/ && cp Info.plist build/Islet.app/Contents/
codesign --force --deep --sign - build/Islet.app
cp -R build/Islet.app build/dmg/ && ln -s /Applications build/dmg/Applications
hdiutil create -volname Islet -srcfolder build/dmg -ov -format UDZO build/Islet.dmg
echo "Built build/Islet.dmg"
