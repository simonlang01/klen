#!/bin/bash
# Usage: ./ship.sh <version> <build>
# Example: ./ship.sh 1.6 3
# Merges dev → main, builds, signs, updates appcast, pushes.

set -e

VERSION=${1:?"Usage: ./ship.sh <version> <build>  (e.g. ./ship.sh 1.6 3)"}
BUILD=${2:?"Usage: ./ship.sh <version> <build>  (e.g. ./ship.sh 1.6 3)"}
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Make sure we're on dev and everything is committed
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "dev" ]; then
    echo "✗ You must be on the dev branch to ship. Current branch: $BRANCH"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "✗ You have uncommitted changes. Commit or stash them first."
    git status --short
    exit 1
fi

echo "→ Pushing dev to GitHub..."
git push origin dev

echo "→ Merging dev into main..."
git checkout main
git pull origin main
git merge dev --no-edit

echo "→ Running release script..."
"$REPO_ROOT/release.sh" "$VERSION" "$BUILD"

echo "→ Committing and pushing release..."
git add appcast.xml dist/appcast.xml Plink/Info.plist
git commit -m "Release $VERSION"
git push origin main

echo "→ Switching back to dev..."
git checkout dev
git merge main --no-edit
git push origin dev

echo ""
echo "✓ Shipped v$VERSION (build $BUILD)."
echo ""
echo "  Last step — create the GitHub Release:"
echo "  1. Go to: https://github.com/simonlang01/plink/releases/new"
echo "  2. Tag: v$VERSION"
echo "  3. Upload: $REPO_ROOT/dist/Plink-$VERSION.dmg"
echo "  4. Publish"
echo ""
echo "  Users will be notified automatically on next launch."
