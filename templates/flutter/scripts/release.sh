#!/usr/bin/env bash

set -euo pipefail

if [ "$(git branch --show-current)" != "main" ]; then
  echo "Stable releases must be created from main." >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree must be clean before creating a release tag." >&2
  exit 1
fi

git fetch origin main --tags
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "Local main must exactly match origin/main before releasing." >&2
  exit 1
fi

VERSION=$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' pubspec.yaml | head -n 1)
TAG="v$VERSION"
if [ -z "$VERSION" ] || git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Set a new version in pubspec.yaml before releasing." >&2
  exit 1
fi

git tag -a "$TAG" -m "APP_NAME $VERSION"
git push origin "$TAG"

