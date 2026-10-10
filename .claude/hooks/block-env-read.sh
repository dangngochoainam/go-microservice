#!/usr/bin/env bash
# PreToolUse hook: không cho Claude đọc file secret .env (và .env.*), trừ
# .env.example. Áp dụng cho tool đọc/sửa file và cho lệnh Bash nhắc tới .env.
set -euo pipefail

input="$(cat)"

# Bỏ mọi '.env.example' đi rồi mới tìm '.env' hoặc '.env.<gì đó>'.
mentions_env() {
  sed 's/\.env\.example//g' | grep -qE '(^|[^[:alnum:]_])\.env([^[:alnum:]_-]|$)'
}

tool="$(jq -r '.tool_name // empty' <<<"$input")"
if [ "$tool" = "Bash" ]; then
  target="$(jq -r '.tool_input.command // empty' <<<"$input")"
else
  # Grep: chỉ xét path/glob, không xét regex tìm kiếm.
  target="$(jq -r '[.tool_input.file_path, .tool_input.notebook_path, .tool_input.path, .tool_input.glob] | map(select(. != null)) | join(" ")' <<<"$input")"
fi

mentions_env <<<"$target" || exit 0

cat >&2 <<EOF
Không được đọc file secret .env (chỉ .env.example được phép). Cần biết key nào
thì đọc .env.example hoặc configs/config.go. Nếu cần tạo .env, nhờ người dùng tự
chạy, ví dụ: ! cp .env.example .env
EOF
exit 2
