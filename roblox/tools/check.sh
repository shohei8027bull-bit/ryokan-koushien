#!/usr/bin/env bash
# Luau スクリプトの文法チェック。初回のみ luau-compile を .cache/ にダウンロードします。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/.cache/luau"
COMPILE="$BIN_DIR/luau-compile"

if [ ! -x "$COMPILE" ]; then
	mkdir -p "$BIN_DIR"
	curl -sSL -o "$BIN_DIR/luau.zip" https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
	unzip -o -q "$BIN_DIR/luau.zip" -d "$BIN_DIR"
fi

status=0
while IFS= read -r file; do
	if "$COMPILE" --null "$file" >/dev/null; then
		echo "OK   ${file#"$ROOT"/}"
	else
		echo "NG   ${file#"$ROOT"/}"
		status=1
	fi
done < <(find "$ROOT/src" -name '*.luau' | sort)

exit $status
