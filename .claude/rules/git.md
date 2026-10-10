# Commit và push

Không `git commit`, `git push` hay tạo PR khi người dùng chưa cho phép rõ ràng trong lượt hiện tại. Cho phép lần trước không áp dụng cho lần sau.

- Xong việc và verify PASS: dừng ở trạng thái chưa commit, báo các thay đổi kèm commit message đề xuất, rồi chờ.
- Người dùng cho phép commit không có nghĩa là cho phép push; push và tạo PR cần được cho phép riêng.
- Không bao giờ push hay merge thẳng vào `master`/`main` (permission deny + hook `block-master-push.sh` chặn), kể cả repo root workspace: commit trên nhánh riêng, push nhánh đó, mở PR; người dùng tự merge.
- Trước khi commit, xem `git status`. Nếu người dùng đã stage sẵn thì commit đúng phần đã stage: không unstage, không `git add` thêm. Phần đã stage khác với cách chia commit đã thống nhất thì báo lại và hỏi, không tự sửa.
