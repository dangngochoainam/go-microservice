# Nguồn

Chép từ `skills/writing-plans/SKILL.md` của https://github.com/obra/superpowers, commit `bb92a77741419a4ab5f06e711a283343f1ada0c3` (MIT, xem `LICENSE`).

Đã sửa so với bản gốc (áp lại khi cập nhật từ upstream):

- `description`: chỉ kích hoạt cho task cỡ project có design doc đã duyệt, không cho task nhỏ làm trong một session.
- "Context": worktree tạo bằng `scripts/task-start.sh` thay cho `superpowers:using-git-worktrees`; đường dẫn file trong plan bắt đầu bằng tên repo.
- "Save plans to": `plans/<task-name>/plan.md` thay cho `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`.
- Header plan: thêm dòng `Status: draft` (theo `.claude/rules/plans.md`) và mục `**Repos:**`; dòng "For agentic workers" trỏ tới rules thay cho `superpowers:subagent-driven-development` / `superpowers:executing-plans`.
- "What a Step Contains": test step ghi rõ loại test (unit / integration / e2e) theo skill `writing-tests`.
- "Execution Handoff": bỏ lựa chọn Subagent-driven / Native vì không có hai skill thực thi đó; sau khi plan được duyệt là skill `writing-tests` (viết và khóa test), rồi implement trong session theo rules. Chép thêm `subagent-driven-development` nếu cần lại lựa chọn này.
