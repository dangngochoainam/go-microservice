#!/usr/bin/env bash
# Tạo worktrees/<name>/<repo> cho mỗi repo cần cho task, checkout từ
# origin/master mới nhất, rồi chạy `make mod` trong từng worktree.
#
#   scripts/task-start.sh <name> <repo>...
#
# gopkg và gm-core luôn được thêm vào: mọi go.mod dùng replace ../gopkg và
# ../gm-core, nên chúng phải nằm cạnh repo service trong cùng thư mục task.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 2 ]; then
  echo "usage: $0 <name> <repo>..." >&2
  exit 1
fi

name="$1"
shift
if ! [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "tên task chỉ gồm a-z, 0-9, '-': $name" >&2
  exit 1
fi

# gopkg, gm-core trước để make mod của service resolve được replace.
repos=(gopkg gm-core)
for r in "$@"; do
  [[ " ${repos[*]} " == *" $r "* ]] || repos+=("$r")
done

task_dir="$ROOT/worktrees/$name"

# Kiểm tra và fetch hết trước khi tạo gì, để không bỏ dở giữa chừng.
for r in "${repos[@]}"; do
  [ -e "$ROOT/$r/.git" ] || { echo "$r: không phải repo trong workspace" >&2; exit 1; }
  [ -e "$task_dir/$r" ] && continue
  if git -C "$ROOT/$r" show-ref --verify --quiet "refs/heads/$name"; then
    echo "$r: nhánh '$name' đã tồn tại" >&2
    exit 1
  fi
  git -C "$ROOT/$r" fetch --quiet origin master 2>/dev/null \
    || { echo "$r: origin chưa có nhánh master" >&2; exit 1; }
done

for r in "${repos[@]}"; do
  if [ -e "$task_dir/$r" ]; then
    echo "$r: đã có $task_dir/$r, bỏ qua"
    continue
  fi
  git -C "$ROOT/$r" worktree add --quiet --no-track -b "$name" "$task_dir/$r" origin/master
  echo "$r: tạo worktree từ origin/master"
done

for r in "${repos[@]}"; do
  if grep -q '^mod:' "$task_dir/$r/Makefile" 2>/dev/null; then
    echo "$r: make mod"
    make -C "$task_dir/$r" --no-print-directory mod
  fi
done

echo "xong: $task_dir"
