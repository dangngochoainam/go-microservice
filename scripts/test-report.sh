#!/usr/bin/env bash
# Chạy integration hoặc e2e test của một task và ghi bằng chứng vào
# reports/<task>/<thời-gian>-<level>-<mode>.md. Env do người dùng cung cấp
# phải được export trước khi gọi script.
#
#   scripts/test-report.sh <task-name> <integration|e2e> <mode>
#
# Report được ghi cả khi test fail; script trả về exit code của test.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -ne 3 ]; then
  echo "usage: $0 <task-name> <integration|e2e> <mode>" >&2
  exit 1
fi
task="$1" level="$2" mode="$3"

case "$level" in
  integration|e2e) ;;
  *) echo "level phải là integration hoặc e2e: $level" >&2; exit 1 ;;
esac
if ! [[ "$mode" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "mode chỉ gồm a-z, 0-9, '-': $mode" >&2
  exit 1
fi

task_dir="$ROOT/worktrees/$task"
[ -d "$task_dir" ] || { echo "không có $task_dir" >&2; exit 1; }

# Repo cần chạy: e2e chỉ ở gm-gateway/e2e; integration ở mọi repo có file mang tag.
repos=()
if [ "$level" = e2e ]; then
  [ -d "$task_dir/gm-gateway/e2e" ] || { echo "không có $task_dir/gm-gateway/e2e" >&2; exit 1; }
  repos=(gm-gateway)
  pkgs=./e2e/...
else
  for d in "$task_dir"/*/; do
    r="$(basename "$d")"
    grep -rlq --include='*_test.go' --exclude-dir=vendor '^//go:build integration' "$d" 2>/dev/null && repos+=("$r")
  done
  [ ${#repos[@]} -gt 0 ] || { echo "không repo nào trong $task_dir có test //go:build integration" >&2; exit 1; }
  pkgs=./...
fi

out_dir="$ROOT/reports/$task"
mkdir -p "$out_dir"
started="$(date -Iseconds)"
report="$out_dir/$(date +%Y%m%d-%H%M%S)-$level-$mode.md"

status=0
{
  echo "# $level test — $task"
  echo
  echo "- Mode: \`$mode\`"
  echo "- Bắt đầu: $started"
  echo "- Máy: $(hostname)"
  echo "- Go: $(cd "$task_dir/${repos[0]}" && go version)"
  echo
  echo "## Env"
  echo
  echo '```'
  env | grep -E '^(DATABASE_|E2E_|REDIS|RABBIT|MONGO)' | sort \
    | sed -E 's/^([^=]*(PASSWORD|SECRET|TOKEN|KEY)[^=]*)=.*/\1=***/'
  echo '```'
  echo
  echo "## Code"
  echo
  echo "| Repo | Nhánh | Commit | File chưa commit |"
  echo "|---|---|---|---|"
  for r in "${repos[@]}"; do
    echo "| $r | $(git -C "$task_dir/$r" branch --show-current) | $(git -C "$task_dir/$r" rev-parse --short HEAD) | $(git -C "$task_dir/$r" status --porcelain | wc -l) |"
  done
  for r in "${repos[@]}"; do
    echo
    echo "## $r: \`go test -count=1 -tags $level -v $pkgs\`"
    echo
    echo '```'
    (cd "$task_dir/$r" && go test -count=1 -tags "$level" -v $pkgs 2>&1)
    code=$?
    echo '```'
    echo
    echo "Exit code: $code"
    [ $code -eq 0 ] || status=$code
  done
  echo
  echo "## Kết quả"
  echo
  echo "- Kết thúc: $(date -Iseconds)"
  if [ $status -eq 0 ]; then echo "- **PASS**"; else echo "- **FAIL** (exit $status)"; fi
} >"$report"

echo "report: ${report#"$ROOT"/}"
if [ $status -eq 0 ]; then echo "PASS"; else echo "FAIL (exit $status)"; fi
exit $status
