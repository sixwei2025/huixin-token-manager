#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/vendor/engine"
if [[ -x "$ENGINE/CodexBarCLI" && -d "$ENGINE/CodexBar_CodexBarCore.bundle" ]]; then exit 0; fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
URL='https://github.com/steipete/CodexBar/releases/download/v0.84.0/CodexBar-macos-universal-0.84.0.zip'
curl --fail --location --retry 2 "$URL" -o "$TMP/upstream.zip"
echo 'c1da2faaa9608f8798306c300804d3720782656f955d736d18bcac476b77ed2c  '"$TMP/upstream.zip" | shasum -a 256 -c -
ditto -x -k "$TMP/upstream.zip" "$TMP/unpacked"
mkdir -p "$ENGINE"
ditto "$TMP/unpacked/CodexBar.app/Contents/Helpers" "$ENGINE"
