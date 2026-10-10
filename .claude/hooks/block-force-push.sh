#!/usr/bin/env bash
# PreToolUse hook (Bash): chặn mọi dạng force push. permissions.deny chỉ khớp
# theo prefix nên không bắt được `git -C x push -f`, `git push origin +main`,
# `-uf`... Hook này bắt các biến thể đó.
set -euo pipefail

cmd="$(jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

# Chỉ xét lệnh có `git ... push`.
grep -qE '(^|[^[:alnum:]_-])git([[:space:]]+[^;&|]*)?[[:space:]]push([[:space:]]|$)' <<<"$cmd" || exit 0

# --force, --force-with-lease, --force-if-includes, -f gộp cờ (-uf), refspec +ref.
if grep -qE '[[:space:]](--force([-=[:alnum:]]*)?|-[[:alpha:]]*f[[:alpha:]]*|\+[^[:space:]]+)([[:space:]]|$)' <<<"$cmd"; then
  cat >&2 <<EOF
Force push bị cấm trong workspace này (kể cả --force-with-lease và refspec '+ref').
Nếu nhánh lệch với remote, rebase/merge rồi push thường, hoặc báo người dùng tự xử lý.
EOF
  exit 2
fi
