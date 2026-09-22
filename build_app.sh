#!/bin/bash
set -e

# Default version if not provided
VERSION="${1:-1.0.0}"
APP_NAME="Disk Analyzer"
EXECUTABLE_NAME="DiskAnalyzer"
BUNDLE_ID="com.diskanalyzer.app"

echo "Building $APP_NAME version $VERSION..."

# Build the Swift package in release mode (Universal Binary)
if swift build -c release --arch arm64 --arch x86_64; then
    EXECUTABLE_PATH=".build/apple/Products/Release/$EXECUTABLE_NAME"
else
    # Fallback to single architecture
    echo "Universal build failed, falling back to single architecture build..."
    swift build -c release
    EXECUTABLE_PATH="$(swift build -c release --show-bin-path)/$EXECUTABLE_NAME"
fi

# Paths
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Create App bundle structure
echo "Creating App bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
echo "Copying executable..."
if [ -f "$EXECUTABLE_PATH" ]; then
    cp "$EXECUTABLE_PATH" "$MACOS_DIR/"
else
    echo "Error: Executable not found at $EXECUTABLE_PATH"
    exit 1
fi

# Generate and copy App Icon if running on macOS (using iconutil) or copy a fallback
echo "Generating AppIcon.icns..."
if command -v iconutil >/dev/null 2>&1; then
    mkdir -p AppIcon.iconset
    sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png
    sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png
    sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png
    sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png
    sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png
    sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png
    sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png
    sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png
    sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png
    sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png
    iconutil -c icns AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf AppIcon.iconset
else
    echo "iconutil not found (likely not on macOS), skipping .icns generation."
fi

# Create Info.plist
echo "Generating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Done! $APP_DIR created."
