#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="$(sed -n 's/^name: *//p' "$ROOT/project.yml" | head -n 1)"
VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$ROOT/project.yml" | head -n 1)"
OUT="$ROOT/dist"
WORK="$ROOT/.build/xcode"
LOG="$WORK/build.log"
LAST="$( (ls -1 "$OUT" 2>/dev/null || true) | sed -n "s/^$NAME \([0-9][0-9]*\)\.app$/\1/p" | sort -n | tail -n 1)"
LAST="${LAST:-1000}"
NUMBER=$((LAST + 1))
TARGET="$OUT/$NAME $NUMBER.app"

mkdir -p "$WORK" "$OUT"
: >"$LOG"

cd "$ROOT"
xcodegen generate >>"$LOG" 2>&1 || { tail -n 30 "$LOG" >&2; exit 1; }
xcodebuild -project "$NAME.xcodeproj" -scheme "$NAME" -configuration Debug \
  -derivedDataPath "$WORK" CURRENT_PROJECT_VERSION="$NUMBER" build -quiet >>"$LOG" 2>&1 || { tail -n 30 "$LOG" >&2; exit 1; }

rm -rf "$TARGET"
ditto "$WORK/Build/Products/Debug/$NAME.app" "$TARGET"
find "$OUT" -maxdepth 1 -name "$NAME*.app" ! -name "$NAME $NUMBER.app" ! -name "$NAME $LAST.app" -exec rm -rf {} +
echo "$TARGET ($VERSION, build $NUMBER)"
