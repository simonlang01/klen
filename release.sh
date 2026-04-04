#!/bin/bash
# Usage: ./release.sh 1.6
# Builds a new Release DMG, signs it, and updates appcast.xml

set -e

VERSION=${1:?"Usage: ./release.sh <version> <build>  (e.g. ./release.sh 1.6 2)"}
BUILD=${2:?"Usage: ./release.sh <version> <build>  (e.g. ./release.sh 1.6 2)"}
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA=~/Library/Developer/Xcode/DerivedData/Plink-dbykklctfnorzibkynxpvuyluoxw
SIGN_UPDATE="$REPO_ROOT/build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
DMG="$REPO_ROOT/dist/Plink-$VERSION.dmg"
APP="$DERIVED_DATA/Build/Products/Release/Plink.app"

echo "→ Updating version to $VERSION (build $BUILD)..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$REPO_ROOT/Plink/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$REPO_ROOT/Plink/Info.plist"

echo "→ Building Release..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$REPO_ROOT/Plink.xcodeproj" \
  -scheme Plink -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$REPO_ROOT/build/SourcePackages" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build | grep -E "error:|BUILD"

echo "→ Creating DMG..."
rm -f "$DMG"
create-dmg \
  --volname "Plink" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 --window-size 660 400 \
  --icon-size 128 --icon "Plink.app" 165 185 \
  --hide-extension "Plink.app" --app-drop-link 495 185 \
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
        <title>Plink</title>
        <link>https://raw.githubusercontent.com/simonlang01/plink/main/appcast.xml</link>
        <description>Plink update feed</description>
        <language>en</language>

        <item>
            <title>Plink $VERSION</title>
            <pubDate>$DATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>https://github.com/simonlang01/plink/releases/tag/v$VERSION</sparkle:releaseNotesLink>
            <enclosure
                url="https://github.com/simonlang01/plink/releases/download/v$VERSION/Plink-$VERSION.dmg"
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
