# Quy trình plan

Plan nằm trong `plans/` ở root workspace (đặt bởi `plansDirectory` trong `.claude/settings.json`), không nằm trong repo con, vì một plan thường đụng nhiều repo. Mỗi task một thư mục `plans/<tên-task>/` chứa mọi tài liệu của task đó.

## Khi nào cần plan ra file

Chỉ task cỡ project (theo mục "Size the Work" của skill `brainstorming`) mới có design doc và plan trong `plans/`. Task nhanh hoặc thay đổi nhỏ, làm xong được trong một session, thì chốt mô tả trong chat rồi làm luôn, không tạo file plan; các mục dưới đây không áp dụng. Nếu task nhỏ phình ra giữa chừng, dừng lại, báo, và chuyển sang lập plan.

## Lưu plan

- Mỗi việc một thư mục, tên `<repo>-<chủ-đề>`, ví dụ `plans/gm-order-scaffold/`. Việc đụng nhiều repo thì dùng `workspace-<chủ-đề>`.
- Trong thư mục task:

  | File | Ai viết | Nội dung |
  |---|---|---|
  | `design.md` | skill `brainstorming` | tài liệu thiết kế, không phải plan |
  | `plan.md` | skill `writing-plans` | plan |
  | `tests.md` | skill `writing-tests` | mọi kịch bản test của task (happy, edge, biên, xử lý lỗi; unit, integration, e2e) và report |

- Code test (`*_test.go`) vẫn nằm trong repo, cạnh package nó test: Go không compile được test ở chỗ khác. `tests.md` chỉ trỏ tới nó.
- Nếu plan được viết bằng plan mode thay vì skill, ngay sau khi plan được duyệt, chuyển file plan mode vừa ghi thành `plans/<tên-task>/plan.md`.
- Dòng đầu tiên sau tiêu đề: `Status: draft | approved | in-progress | done`.
- Các bước viết dạng checklist `- [ ]`, mỗi bước kèm cách verify.

## Implement

- Trước khi implement task cỡ project, đọc plan được chỉ định. Nếu không được chỉ định, tìm trong `plans/*/plan.md` file có `Status: in-progress` hoặc `approved`. Không có hoặc có nhiều hơn một thì hỏi, không tự đoán.
- Trước khi viết code, test của plan phải đã được viết và khóa theo skill `writing-tests`.
- Khi bắt đầu, đặt `Status: in-progress`.
- Xong mỗi bước thì tick `- [x]` ngay, không dồn đến cuối.
- Làm lệch plan thì ghi vào mục `## Thay đổi so với plan` cuối file, kèm lý do.
- Xong toàn bộ thì đặt `Status: done`.
