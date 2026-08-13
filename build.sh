#!/usr/bin/env bash
#
# Build ClipStack into a runnable .app bundle.
#
#   ./build.sh                                   # ad-hoc signed (re-grant Accessibility per rebuild)
#   CODESIGN_IDENTITY="ClipStack Self-Signed" ./build.sh   # stable signature (grant persists)
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ClipStack"
SRC_DIR="ClipStack"
OUT_DIR="build"
APP="$OUT_DIR/$APP_NAME.app"
IDENTITY="${CODESIGN_IDENTITY:--}"   # "-" = ad-hoc
ARCH="$(uname -m)"                    # arm64 or x86_64

echo "▸ Compiling ($ARCH, macOS 14+)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -swift-version 5 -target "${ARCH}-apple-macos14.0" \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  "$SRC_DIR"/*.swift \
  -framework SwiftUI -framework AppKit -framework ServiceManagement

echo "▸ Signing (identity: $IDENTITY)…"
codesign --force --deep --sign "$IDENTITY" \
  --identifier com.morpheusdesk.clipstack "$APP"

echo "✓ Built $APP"
echo
echo "Next steps:"
echo "  cp -R \"$APP\" ~/Applications/"
echo "  open ~/Applications/$APP_NAME.app"
echo "  # then grant Accessibility when prompted (enables auto-paste)"
