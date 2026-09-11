#!/bin/sh
# Release a new Foldy version.
#   Scripts/release.sh 0.2.0 [--skip-build]
#
# Swift Package Manager versions are git tags, so a release is:
#   1. Check that main is clean and in sync with origin, and the tag is new.
#   2. Build the package for the iOS Simulator (skip with --skip-build).
#   3. Point the README install snippet at the new version and commit it.
#   4. Create an annotated tag, push main and the tag.
#   5. Create the GitHub release with generated notes.
set -e

version=$1
case "$version" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "usage: Scripts/release.sh <major.minor.patch> [--skip-build]" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."

[ "$(git branch --show-current)" = main ] || { echo "switch to main first" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree is not clean" >&2; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "main is not in sync with origin/main" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
  echo "tag $version already exists" >&2; exit 1
fi

if [ "$2" != "--skip-build" ]; then
  echo "Building Foldy for the iOS Simulator"
  xcodebuild -scheme Foldy -destination 'generic/platform=iOS Simulator' -quiet build
fi

sed -i '' "s|Foldy.git\", from: \"[0-9.]*\"|Foldy.git\", from: \"$version\"|" README.md
if ! git diff --quiet -- README.md; then
  git commit -qm "Release $version" README.md
fi

git tag -a "$version" -m "Foldy $version"
git push -q origin main "$version"
gh release create "$version" --title "$version" --generate-notes
echo "Released Foldy $version"
