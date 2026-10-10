#!/usr/bin/env bash
# Stop hook: trước khi Claude kết thúc lượt, chạy scripts/verify.sh cho mọi
# repo trong worktrees/ đã thay đổi kể từ lần verify PASS gần nhất. Fail thì
# chặn kết thúc và đưa lỗi cho Claude sửa, tối đa MAX_BLOCKS lần liên tiếp
# trong một lượt; quá thì để Claude dừng và báo người dùng.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MAX_BLOCKS=3
counter="$ROOT/worktrees/.verify-blocks"

active="$(jq -r '.stop_hook_active // false')"
[ -d "$ROOT/worktrees" ] || exit 0
[ "$active" = true ] || rm -f "$counter"

# Dấu vân tay của trạng thái repo: HEAD + file thay đổi + nội dung diff.
fingerprint() {
  { git -C "$1" rev-parse HEAD; git -C "$1" status --porcelain; git -C "$1" diff HEAD; } | sha256sum | cut -d' ' -f1
}

out=""
status=0
for task_dir in "$ROOT"/worktrees/*/; do
  task="$(basename "$task_dir")"
  ok_file="$task_dir.verify-ok"
  changed=()
  for d in "$task_dir"*/; do
    [ -e "$d.git" ] || continue
    r="$(basename "$d")"
    # Repo chưa đụng tới (vẫn đúng origin/master, không thay đổi) thì bỏ qua.
    if [ "$(git -C "$d" rev-parse HEAD)" = "$(git -C "$d" rev-parse origin/master 2>/dev/null)" ] \
      && [ -z "$(git -C "$d" status --porcelain)" ]; then
      continue
    fi
    grep -qxF "$r $(fingerprint "$d")" "$ok_file" 2>/dev/null || changed+=("$r")
  done
  [ ${#changed[@]} -gt 0 ] || continue

  if res="$("$ROOT/scripts/verify.sh" "$task" "${changed[@]}" 2>&1)"; then
    for r in "${changed[@]}"; do
      grep -v "^$r " "$ok_file" 2>/dev/null >"$ok_file.tmp" || true
      echo "$r $(fingerprint "$task_dir$r")" >>"$ok_file.tmp"
      mv "$ok_file.tmp" "$ok_file"
    done
  else
    status=1
    out+="### task $task: ${changed[*]}"$'\n'"$(tail -n 60 <<<"$res")"$'\n'
  fi
done

if [ $status -eq 0 ]; then
  rm -f "$counter"
  exit 0
fi

n=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$n" >"$counter"
if [ "$n" -gt "$MAX_BLOCKS" ]; then
  rm -f "$counter"
  jq -n --arg m "verify vẫn FAIL sau $MAX_BLOCKS lần sửa; Claude dừng lại. Xem output của scripts/verify.sh." '{systemMessage: $m}'
  exit 0
fi

{
  echo "verify FAIL (lần $n/$MAX_BLOCKS). Sửa lỗi dưới đây rồi mới kết thúc. Nếu lỗi cần người dùng quyết (test đã khóa, lint có sẵn từ trước, thiếu env), đừng lách: dừng và trình người dùng."
  echo
  echo "$out"
} >&2
exit 2
