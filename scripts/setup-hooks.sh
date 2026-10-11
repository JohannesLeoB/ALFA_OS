#!/bin/sh
ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
git -C "$ROOT" config core.hooksPath .githooks || exit 1
for hook in "$ROOT"/.githooks/*; do
  [ -x "$hook" ] || chmod +x "$hook"
done
echo "core.hooksPath is .githooks in $ROOT"
