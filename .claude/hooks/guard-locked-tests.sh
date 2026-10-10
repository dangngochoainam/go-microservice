#!/usr/bin/env bash
# PreToolUse hook: test đã khóa (liệt kê trong worktrees/<task>/.tests-lock)
# và chính file lock chỉ được sửa khi người dùng duyệt. Mode có prompt thì
# hỏi; mode không hiện prompt thì chặn hẳn. Bằng chứng trong reports/ thì
# luôn bị chặn.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

input="$(cat)"
path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
[ -n "$path" ] || exit 0
mode="$(jq -r '.permission_mode // "default"' <<<"$input")"

abs="$(realpath -m "$path")"

# Bằng chứng test chỉ do scripts/test-report.sh ghi, không ai sửa tay.
case "$abs" in
  "$ROOT"/reports/*)
    echo "reports/ là bằng chứng test, chỉ scripts/test-report.sh được ghi vào đó. Không sửa hay tạo file ở đây bằng Edit/Write." >&2
    exit 2
    ;;
esac

case "$abs" in
  "$ROOT"/worktrees/*/*) ;;
  *) exit 0 ;;
esac

rel="${abs#"$ROOT"/worktrees/}"
task="${rel%%/*}"
rel="${rel#*/}"
lock="$ROOT/worktrees/$task/.tests-lock"
[ -f "$lock" ] || exit 0
# Dòng trong lock là một file, hoặc một thư mục nếu kết thúc bằng '/'.
locked=false
[ "$rel" = ".tests-lock" ] && locked=true
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  case "$entry" in
    */) [[ "$rel" == "$entry"* ]] && locked=true ;;
    *) [ "$rel" = "$entry" ] && locked=true ;;
  esac
done <"$lock"
$locked || exit 0

reason="'$rel' là test đã khóa của task '$task'. Chỉ sửa khi người dùng đồng ý (xem skill writing-tests)."

case "$mode" in
  default|acceptEdits)
    jq -n --arg r "$reason" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
    ;;
  *)
    echo "$reason Mode '$mode' không hiện prompt duyệt: trình lý do và diff đề xuất trong chat; nếu người dùng đồng ý, họ chuyển sang default mode (Shift+Tab) rồi bạn thử lại." >&2
    exit 2
    ;;
esac
