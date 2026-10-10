#!/usr/bin/env bash
# PreToolUse hook (Bash): cấm push và merge thẳng vào master/main. permissions.deny
# chỉ khớp theo prefix nên không bắt được `git push` trơn khi đang đứng trên
# master, `HEAD:master`, hay `git merge` trên master. Hook này bắt các biến thể đó.
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
[ -n "$cmd" ] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input")"

block() {
  cat >&2 <<EOF
$1
Push lên nhánh task rồi mở PR; việc merge vào master do người dùng làm.
EOF
  exit 2
}

# Nhánh hiện tại của repo mà lệnh nhắm tới: theo `git -C <dir>` nếu có, không thì cwd.
current_branch() {
  local dir
  dir="$(grep -oE 'git[[:space:]]+-C[[:space:]]+[^[:space:];&|]+' <<<"$cmd" | head -1 | awk '{print $3}')"
  [ -n "$dir" ] || dir="$cwd"
  [[ "$dir" = /* ]] || dir="$cwd/$dir"
  git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || true
}

is_main() { [ "$1" = master ] || [ "$1" = main ]; }

GIT='(^|[^[:alnum:]_-])git([[:space:]]+-C[[:space:]]+[^[:space:];&|]+)?[[:space:]]+'

if grep -qE "${GIT}push([[:space:]]|$)" <<<"$cmd"; then
  # Refspec đích là master/main: `master`, `:master`, `HEAD:refs/heads/master`.
  if grep -qE '[[:space:]]([^[:space:]]*:)?(refs/heads/)?(master|main)([[:space:]]|$)' <<<"$cmd"; then
    block "Push thẳng vào master/main bị cấm trong workspace này."
  fi
  if is_main "$(current_branch)"; then
    block "Đang đứng trên master/main: \`git push\` sẽ push thẳng vào master/main."
  fi
fi

if grep -qE "${GIT}merge([[:space:]]|$)" <<<"$cmd" && is_main "$(current_branch)"; then
  block "Merge vào master/main bị cấm trong workspace này."
fi

if grep -qE '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)' <<<"$cmd"; then
  block "Merge PR (\`gh pr merge\`) bị cấm trong workspace này."
fi

exit 0
