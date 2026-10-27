#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="$(sed -n 's/^name: *//p' "$ROOT/project.yml" | head -n 1)"
VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$ROOT/project.yml" | head -n 1)"
BUILD="$(sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$ROOT/project.yml" | head -n 1)"
OUT="$ROOT/dist/$NAME"
WORK="$OUT/build"
LOG="$WORK/build.log"
TARGET="$OUT/$NAME-$VERSION.app"

mkdir -p "$WORK"
: >"$LOG"

cd "$ROOT"
xcodegen generate >>"$LOG" 2>&1 || { tail -n 30 "$LOG" >&2; exit 1; }
xcodebuild -project "$NAME.xcodeproj" -scheme "$NAME" -configuration Debug \
  -derivedDataPath "$WORK" CURRENT_PROJECT_VERSION="$BUILD" build -quiet >>"$LOG" 2>&1 || { tail -n 30 "$LOG" >&2; exit 1; }

rm -rf "$TARGET"
ditto "$WORK/Build/Products/Debug/$NAME.app" "$TARGET"
echo "$TARGET"
