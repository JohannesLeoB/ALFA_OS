#!/bin/bash
set -euo pipefail

BUNDLE_ID="com.johannesleoberger.alfaos"
KEEP=2

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: scripts/build_app.sh [--keep-running]"
  echo "Builds dist/ALFA OS <N>.app (N = commit count), keeps the two newest; --keep-running skips quitting the app."
  exit 0
fi

KEEP_RUNNING=0
if [ "${1:-}" = "--keep-running" ]; then
  KEEP_RUNNING=1
elif [ $# -gt 0 ]; then
  echo "Unknown argument: $1 (see --help)" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$DIST/build"
LOG="$WORK/build.log"

N="$(git -C "$ROOT" rev-list --count HEAD)"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
NOTE=""
if [ "$BRANCH" != "main" ]; then
  NOTE="$NOTE branch=$BRANCH"
fi
if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]; then
  NOTE="$NOTE -dirty"
fi
echo "Build $N, commit $COMMIT$NOTE"

is_running() {
  pgrep -f "/Contents/MacOS/ALFA_OS" >/dev/null 2>&1
}

if [ "$KEEP_RUNNING" -eq 0 ] && is_running; then
  osascript -e "quit app id \"$BUNDLE_ID\"" >/dev/null 2>&1 || true
  waited=0
  while is_running; do
    if [ "$waited" -ge 10 ]; then
      echo "ALFA OS is still running after 10 s (a dialog may be open). Close it and run again." >&2
      exit 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
fi

mkdir -p "$DIST"
rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

(cd "$ROOT/alfaos" && xcodegen >"$LOG" 2>&1) || {
  echo "xcodegen failed. Last 30 log lines:" >&2
  tail -n 30 "$LOG" >&2
  exit 1
}

if ! xcodebuild -project "$ROOT/alfaos/ALFA_OS.xcodeproj" -scheme ALFA_OS -configuration Debug \
  -derivedDataPath "$WORK" CURRENT_PROJECT_VERSION="$N" build -quiet >>"$LOG" 2>&1; then
  echo "Build failed. Last 30 log lines:" >&2
  tail -n 30 "$LOG" >&2
  exit 1
fi

PRODUCT="$WORK/Build/Products/Debug/ALFA_OS.app"
if [ ! -d "$PRODUCT" ]; then
  echo "Product not found: $PRODUCT" >&2
  exit 1
fi

TARGET="$DIST/ALFA OS $N.app"
rm -rf "$TARGET"
ditto "$PRODUCT" "$TARGET"

is_ours() {
  local id
  id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$1/Contents/Info.plist" 2>/dev/null || true)"
  [ "$id" = "$BUNDLE_ID" ]
}

for old in "$DIST"/ALFA_OS-*.app; do
  [ -d "$old" ] || continue
  if is_ours "$old"; then
    rm -rf "$old"
  fi
done

numbered=()
for app in "$DIST"/ALFA\ OS\ *.app; do
  [ -d "$app" ] || continue
  base="${app##*/ALFA OS }"
  num="${base%.app}"
  case "$num" in
    ''|*[!0-9]*) continue ;;
  esac
  numbered+=("$num")
done

if [ "${#numbered[@]}" -gt "$KEEP" ]; then
  doomed=()
  while IFS= read -r num; do
    doomed+=("$num")
  done < <(printf '%s\n' "${numbered[@]}" | sort -n | head -n $(( ${#numbered[@]} - KEEP )))
  for num in "${doomed[@]}"; do
    old="$DIST/ALFA OS $num.app"
    if is_ours "$old"; then
      rm -rf "$old"
    fi
  done
fi

rm -rf "$WORK"

echo
echo "New app: $TARGET"
echo "open \"$TARGET\""
echo "Size of dist/: $(du -sh "$DIST" | cut -f1)"
echo
echo "Fremd in dist/"
found=0
for entry in "$DIST"/* "$DIST"/.[!.]*; do
  [ -e "$entry" ] || continue
  name="${entry##*/}"
  case "$name" in
    "ALFA OS "*.app|master-latest|lead) continue ;;
  esac
  printf '%s\t%s\n' "$(du -sh "$entry" | cut -f1)" "$name"
  found=1
done
if [ "$found" -eq 0 ]; then
  echo "(none)"
fi
