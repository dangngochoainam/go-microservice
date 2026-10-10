#!/usr/bin/env bash
# PostToolUse hook: gofmt file .go vừa sửa trong worktrees/. Lỗi cú pháp thì
# báo lại cho Claude.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

path="$(jq -r '.tool_input.file_path // empty')"
case "$path" in
  "$ROOT"/worktrees/*.go) ;;
  *) exit 0 ;;
esac
[ -f "$path" ] || exit 0

if ! out="$(gofmt -w "$path" 2>&1)"; then
  echo "gofmt lỗi ở $path:" >&2
  echo "$out" >&2
  exit 2
fi
