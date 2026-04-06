#!/bin/bash
# Usage: ./release.sh 1.6
# Builds a new Release DMG, signs it, and updates appcast.xml

set -e

VERSION=${1:?"Usage: ./release.sh <version> <build>  (e.g. ./release.sh 1.6 2)"}
BUILD=${2:?"Usage: ./release.sh <version> <build>  (e.g. ./release.sh 1.6 2)"}
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$REPO_ROOT/build/DerivedData"
SIGN_UPDATE="$REPO_ROOT/build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
DMG="$REPO_ROOT/dist/Klen-$VERSION.dmg"
APP="$DERIVED_DATA/Build/Products/Release/Klen.app"

echo "→ Updating version to $VERSION (build $BUILD)..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$REPO_ROOT/Plink/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$REPO_ROOT/Plink/Info.plist"

echo "→ Building Release..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$REPO_ROOT/Klen.xcodeproj" \
  -scheme Klen -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$REPO_ROOT/build/SourcePackages" \
  CODE_SIGN_IDENTITY="-" \
  build | grep -E "error:|BUILD"

BUILT_VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
if [ "$BUILT_VERSION" != "$VERSION" ]; then
    echo "✗ Version mismatch: built app is $BUILT_VERSION, expected $VERSION. Aborting."
    exit 1
fi

echo "→ Creating DMG..."
rm -f "$DMG"
create-dmg \
  --volname "Klen" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 --window-size 660 400 \
  --icon-size 128 --icon "Klen.app" 165 185 \
  --hide-extension "Klen.app" --app-drop-link 495 185 \
  --no-internet-enable \
  "$DMG" "$APP"

echo "→ Signing DMG..."
SIG_OUTPUT=$("$SIGN_UPDATE" "$DMG")
ED_SIG=$(echo "$SIG_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIG_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

echo "→ Updating appcast.xml..."
APPCAST_CONTENT=$(cat << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Klen</title>
        <link>https://raw.githubusercontent.com/simonlang01/klen/main/appcast.xml</link>
        <description>Klen update feed</description>
        <language>en</language>

        <item>
            <title>Klen $VERSION</title>
            <pubDate>$DATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotes>Bug fixes and stability improvements.</sparkle:releaseNotes>
            <enclosure
                url="https://github.com/simonlang01/klen/releases/download/v$VERSION/Klen-$VERSION.dmg"
                length="$LENGTH"
                type="application/octet-stream"
                sparkle:edSignature="$ED_SIG"
            />
        </item>

    </channel>
</rss>
EOF
)
echo "$APPCAST_CONTENT" > "$REPO_ROOT/dist/appcast.xml"
echo "$APPCAST_CONTENT" > "$REPO_ROOT/appcast.xml"

echo ""
echo "✓ Done. Now:"
echo "  1. Push appcast.xml to GitHub:  git add appcast.xml dist/appcast.xml && git commit -m 'Release $VERSION' && git push"
echo "  2. Create GitHub Release v$VERSION and upload: $DMG"
echo ""
echo "  Existing users will be notified automatically on next launch."
