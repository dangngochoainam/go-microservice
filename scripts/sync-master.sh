#!/usr/bin/env bash
# Kéo master mới nhất từ origin về checkout gốc của repo root workspace và mọi
# repo con. Chỉ fast-forward: không rebase, reset, force, hay đổi nhánh.
# Không đụng worktrees/.
#
#   scripts/sync-master.sh
#
# Repo đang ở nhánh khác: chỉ cập nhật nhánh master local, nhánh hiện tại giữ nguyên.
# Exit 1 nếu có repo bị bỏ qua (fetch lỗi, thay đổi chưa commit, master lệch).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

repos=(.)
for d in "$ROOT"/*/; do
  [ -e "$d/.git" ] && repos+=("$(basename "$d")")
done

attention=()
failed=0

sync_repo() { # <dir> -> in kết quả, trả 1 nếu bỏ qua
  local dir="$1" branch old new
  branch="$(git -C "$dir" branch --show-current)"

  git -C "$dir" fetch --quiet --prune origin 2>/dev/null || { echo "bỏ qua: fetch lỗi"; return 1; }
  new="$(git -C "$dir" rev-parse --verify -q refs/remotes/origin/master)" \
    || { echo "bỏ qua: origin chưa có master"; return 1; }

  old="$(git -C "$dir" rev-parse --verify -q refs/heads/master)"
  if [ -z "$old" ]; then
    git -C "$dir" branch --quiet master origin/master
    echo "tạo master tại ${new:0:7}"
    return 0
  fi
  if [ "$old" = "$new" ]; then
    echo "đã mới nhất"
    return 0
  fi
  if ! git -C "$dir" merge-base --is-ancestor "$old" "$new"; then
    echo "bỏ qua: master local lệch origin/master (có commit chưa có trên remote)"
    return 1
  fi

  if [ "$branch" = master ]; then
    if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
      echo "bỏ qua: có thay đổi chưa commit trên master"
      return 1
    fi
    git -C "$dir" merge --quiet --ff-only origin/master || { echo "bỏ qua: fast-forward lỗi"; return 1; }
  else
    git -C "$dir" update-ref refs/heads/master "$new" "$old"
  fi
  echo "cập nhật ${old:0:7}..${new:0:7}"
}

for r in "${repos[@]}"; do
  name="$r"
  [ "$r" = . ] && name="(workspace)"
  branch="$(git -C "$ROOT/$r" branch --show-current)"
  [ -n "$branch" ] || branch="(detached)"

  result="$(sync_repo "$ROOT/$r")" || { failed=1; attention+=("$name: ${result#bỏ qua: }"); }
  warn=""
  if [ "$branch" != master ]; then
    warn="  ⚠ không ở master"
    attention+=("$name: đang ở nhánh $branch")
  fi
  printf '%-14s %-32s %s%s\n' "$name" "$branch" "$result" "$warn"
done

if [ ${#attention[@]} -gt 0 ]; then
  echo
  echo "Cần để ý:"
  printf '  - %s\n' "${attention[@]}"
fi
exit "$failed"
