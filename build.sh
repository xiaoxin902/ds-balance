#!/bin/sh
# Build DS 余额 without Apelin.
#
# Needs: clang (Xcode Command Line Tools) and an iPhoneOS SDK. Signing is
# optional: codesign on macOS, ldid elsewhere. zip is required.
#
#   SDKROOT=/path/to/iPhoneOS17.2.sdk ./build.sh
#
# Products: build/DSBalance.ipa and build/DSBalance.tipa.
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD="$ROOT/build"
APP="$BUILD/Ds.app"
MIN_IOS="16.0"
ARCHS=${ARCHS:-"arm64 arm64e"}
CC=${CC:-clang}

if [ -z "${SDKROOT:-}" ]; then
    if command -v xcrun >/dev/null 2>&1; then
        SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
    else
        echo "SDKROOT is not set; point it at an iPhoneOS SDK." >&2
        exit 1
    fi
fi
if [ ! -d "$SDKROOT" ]; then
    echo "SDKROOT does not exist: $SDKROOT" >&2
    exit 1
fi

rm -rf "$BUILD"
mkdir -p "$APP"

for arch in $ARCHS; do
    mkdir -p "$BUILD/obj/$arch"
    for src in "$ROOT"/Sources/*.m; do
        obj="$BUILD/obj/$arch/$(basename "$src" .m).o"
        "$CC" -arch "$arch" -miphoneos-version-min="$MIN_IOS" -isysroot "$SDKROOT" \
            -fobjc-arc -Wall -I "$ROOT/Sources" -c "$src" -o "$obj"
    done
    "$CC" -arch "$arch" -miphoneos-version-min="$MIN_IOS" -isysroot "$SDKROOT" \
        -fobjc-arc \
        -framework Foundation -framework UIKit -framework CoreGraphics \
        -framework QuartzCore -framework Security -framework UserNotifications \
        -framework BackgroundTasks \
        "$BUILD"/obj/"$arch"/*.o -o "$BUILD/Ds-$arch"
done

set -- "$BUILD"/Ds-*
if [ "$#" -gt 1 ]; then
    lipo -create "$@" -output "$APP/Ds"
else
    cp "$1" "$APP/Ds"
fi

cp "$ROOT/Resources/Info.plist" "$APP/Info.plist"
cp "$ROOT"/Resources/AppIcon*.png "$APP/"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - --entitlements "$ROOT/Packaging/App.entitlements" "$APP"
elif command -v ldid >/dev/null 2>&1; then
    ldid -S"$ROOT/Packaging/App.entitlements" "$APP/Ds"
else
    echo "No codesign or ldid: the app is unsigned and only TrollStore will accept it." >&2
fi

mkdir -p "$BUILD/Payload"
cp -R "$APP" "$BUILD/Payload/"
rm -f "$BUILD/DSBalance.ipa" "$BUILD/DSBalance.tipa"
(cd "$BUILD" && zip -qry DSBalance.ipa Payload)

# TrollStore looks for this marker inside the bundle.
touch "$APP/_TrollStore"
(cd "$BUILD" && zip -qry DSBalance.tipa Payload)

echo "Built:"
echo "  $BUILD/DSBalance.ipa"
echo "  $BUILD/DSBalance.tipa"
