#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
BUILD_CONFIG="${1:-release}"
case "$BUILD_CONFIG" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;; esac
swift build -c "$BUILD_CONFIG"
BIN_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"
APP_NAME="${BRANCHLET_APP_NAME:-Branchlet}"
BUNDLE_ID="${BRANCHLET_BUNDLE_ID:-com.pjworkspace.branchlet}"
case "$APP_NAME" in Branchlet|Branchlet-QA|Branchlet-Preview) ;; *) echo "Unsupported app name" >&2; exit 2 ;; esac
APP_DIR="${BRANCHLET_OUTPUT_DIR:-$PROJECT_DIR/dist}/$APP_NAME.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/Branchlet" "$APP_DIR/Contents/MacOS/Branchlet"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.pjworkspace.branchlet</string>
<key>CFBundleName</key><string>Branchlet</string>
<key>CFBundleDisplayName</key><string>Branchlet</string>
<key>CFBundleExecutable</key><string>Branchlet</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 PAN JIE. MIT License.</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$APP_DIR/Contents/Info.plist"
cp -R Sources/Branchlet/Resources/en.lproj "$APP_DIR/Contents/Resources/"
cp -R Sources/Branchlet/Resources/zh-Hans.lproj "$APP_DIR/Contents/Resources/"
swift scripts/generate-icon.swift "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built: $APP_DIR"
