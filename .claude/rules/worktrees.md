# Worktree cho mỗi task

Không sửa file trong checkout gốc của repo con (`gopkg/`, `gm-*/`); hook `.claude/hooks/block-root-repo-edits.sh` chặn cứng việc đó. Mọi task làm trong `worktrees/<tên-task>/<repo>/`.

## Bắt đầu task

1. Chọn tên task theo thứ tự ưu tiên:
   - người dùng chỉ định tên → dùng tên đó;
   - task có plan → tên file plan bỏ `.md` (`plans/gm-order-scaffold.md` → `gm-order-scaffold`);
   - còn lại → tự đặt theo quy ước `<repo>-<chủ-đề>` của plan, rồi báo tên cho người dùng.
2. Chạy `scripts/task-start.sh <tên-task> <repo>...` với các repo task sẽ sửa. Script:
   - luôn thêm `gopkg` và `gm-core` (replace `../gopkg`, `../gm-core` phải resolve được);
   - tạo nhánh `<tên-task>` trong mỗi repo, checkout từ `origin/master` mới nhất;
   - chạy `make mod` trong từng worktree.
3. Làm việc, build, test trong `worktrees/<tên-task>/<repo>/`.

Cần thêm repo giữa chừng thì chạy lại script với cùng tên task; worktree đã có sẽ được bỏ qua.
