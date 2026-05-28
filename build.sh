#!/bin/bash
# PClash Build Script
# Usage: ./build.sh [android|macos|all]

set -e

echo "🐌 PClash Build Script"
echo "===================="

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter: $(flutter --version | head -n 1)"

# Get dependencies
echo ""
echo "📦 Getting dependencies..."
flutter pub get

# Check mihomo binaries
echo ""
echo "🔍 Checking mihomo binaries..."
MIHOMO_DIR="assets/mihomo"
MISSING_BINARIES=0

for binary in mihomo-darwin-arm64 mihomo-darwin-amd64 mihomo-android-arm64 mihomo-android-amd64; do
    if [ ! -f "$MIHOMO_DIR/$binary" ]; then
        echo "  ⚠️  Missing: $binary"
        MISSING_BINARIES=$((MISSING_BINARIES + 1))
    else
        echo "  ✅ Found: $binary"
    fi
done

if [ $MISSING_BINARIES -gt 0 ]; then
    echo ""
    echo "⚠️  Warning: $MISSING_BINARIES mihomo binary(ies) missing."
    echo "   Download from: https://github.com/MetaCubeX/mihomo/releases"
    echo "   Place in: $MIHOMO_DIR/"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Build function
build_platform() {
    local platform=$1
    
    echo ""
    echo "🔨 Building for $platform..."
    
    case $platform in
        android)
            flutter build apk --release
            echo ""
            echo "✅ APK built: build/app/outputs/flutter-apk/app-release.apk"
            echo ""
            echo "📱 To install on connected device:"
            echo "   flutter run --release"
            ;;
        macos)
            flutter build macos --release
            echo ""
            echo "✅ macOS app built: build/macos/Build/Products/Release/pclash.app"
            echo ""
            echo "🖥️  To run:"
            echo "   open build/macos/Build/Products/Release/pclash.app"
            ;;
        *)
            echo "❌ Unknown platform: $platform"
            echo "   Supported: android, macos"
            exit 1
            ;;
    esac
}

# Main
PLATFORM=${1:-all}

if [ "$PLATFORM" = "all" ]; then
    build_platform "android"
    build_platform "macos"
else
    build_platform "$PLATFORM"
fi

echo ""
echo "✨ Build complete!"
