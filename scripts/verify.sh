#!/usr/bin/env bash
# Chạy `make verify` (lint + build) trong các repo của một task.
#
#   scripts/verify.sh <task-name> [repo...]   # không truyền repo: mọi repo của task
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "usage: $0 <task-name> [repo...]" >&2
  exit 1
fi
task="$1"
shift
task_dir="$ROOT/worktrees/$task"
[ -d "$task_dir" ] || { echo "không có $task_dir" >&2; exit 1; }

repos=("$@")
if [ ${#repos[@]} -eq 0 ]; then
  for d in "$task_dir"/*/; do
    [ -e "$d/.git" ] && repos+=("$(basename "$d")")
  done
fi

failed=()
for r in "${repos[@]}"; do
  echo "=== $r: make verify"
  if ! grep -q '^verify:' "$task_dir/$r/Makefile" 2>/dev/null; then
    echo "$r: Makefile chưa có target verify"
    failed+=("$r")
    continue
  fi
  make -C "$task_dir/$r" --no-print-directory verify || failed+=("$r")
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "FAIL: ${failed[*]}"
  exit 1
fi
echo "PASS: ${repos[*]}"
