#!/usr/bin/env bash
# PreToolUse hook: chặn Edit/Write vào checkout gốc của các repo con
# (gopkg/, gm-*/). Mọi sửa đổi phải nằm trong worktrees/<task>/<repo>/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
[ -n "$path" ] || exit 0

abs="$(realpath -m "$path")"
case "$abs" in
  "$ROOT"/*) ;;
  *) exit 0 ;;
esac

top="${abs#"$ROOT"/}"
top="${top%%/*}"
[ "$top" != "worktrees" ] || exit 0
[ -e "$ROOT/$top/.git" ] || exit 0

cat >&2 <<EOF
Không được sửa file trong repo gốc '$top/'. Tạo worktree cho task trước:
  scripts/task-start.sh <tên-task> $top [repo khác...]
rồi sửa file trong worktrees/<tên-task>/$top/. Xem .claude/rules/worktrees.md.
EOF
exit 2
