#!/bin/bash
set -euo pipefail

APP_NAME="Domino"
BUNDLE_ID="no.marz.domino"
VERSION="${VERSION:-1.0.0}"
APP_DIR="build/${APP_NAME}.app"

# Build universal binary (arm64 + x86_64)
echo "Building release binary (arm64)..."
swift build -c release --arch arm64

echo "Building release binary (x86_64)..."
swift build -c release --arch x86_64

echo "Creating universal binary..."
mkdir -p .build/universal
lipo -create \
    .build/arm64-apple-macosx/release/$APP_NAME \
    .build/x86_64-apple-macosx/release/$APP_NAME \
    -output .build/universal/$APP_NAME

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/universal/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Sources/Domino/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Copy SPM resource bundle if it exists (check both arch dirs)
for ARCH_DIR in .build/arm64-apple-macosx/release .build/release; do
    if [ -d "$ARCH_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
        cp -R "$ARCH_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_DIR/Contents/Resources/"
        break
    fi
done

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
</dict>
</plist>
PLIST

echo "Done: $APP_DIR"
echo ""
echo "To install:  cp -R \"$APP_DIR\" /Applications/"
echo "To open:     open \"$APP_DIR\""
