---
name: writing-tests
description: Use right after a plan in plans/ is approved and before implementing it - write all of the plan's tests first (TDD: unit, integration, e2e), get them approved, and lock them. Also use whenever a locked test looks wrong during implementation.
---

# Writing Tests

Test viết trước, người dùng chốt, rồi khóa. Sau đó test là thước đo cố định để tự verify phần implement: code phải theo test, không phải test theo code.

**Announce at start:** "Tôi dùng skill writing-tests để viết và khóa test trước khi implement."

## Ba loại test

| Loại | Kiểm tra gì | File | Chạy |
|---|---|---|---|
| unit | một hàm/struct, dependency được fake | `*_test.go`, không build tag | `go test ./...` |
| integration | code thật ↔ hạ tầng thật (Postgres, gRPC handler ↔ DB) | `*_integration_test.go`, dòng đầu `//go:build integration` | `go test -tags integration ./...` |
| e2e | HTTP → `gm-gateway` → gRPC → service → DB | `gm-gateway/e2e/*_test.go`, dòng đầu `//go:build e2e` | `go test -tags e2e ./e2e/...` trong `gm-gateway` |

- `go test ./...` không có tag luôn chạy được mà không cần hạ tầng.
- Integration đọc kết nối từ đúng biến môi trường service dùng (`DATABASE_POSTGRES__HOST`, ...). E2e đọc URL gateway từ `E2E_GATEWAY_URL`.
- Thiếu env thì test gọi `t.Fatal` kèm tên biến còn thiếu, **không** `t.Skip`: skip âm thầm sẽ cho PASS giả.
- Task có e2e thì `gm-gateway` phải nằm trong **Repos** của plan.

## 1. Viết test

1. Đọc plan `plans/<task-name>.md` và design doc nó trỏ tới.
2. Tạo worktree: `scripts/task-start.sh <task-name> <Repos trong plan>`. Mọi file dưới đây nằm trong `worktrees/<task-name>/`.
3. Với mỗi task trong plan, viết test đúng như bước "Write the failing test": đúng loại, đúng tên test, đúng assertion, đúng giá trị plan ghi. Gồm cả test cho các dòng Review Focus.
4. Thêm vừa đủ để test compile, không viết logic:
   - stub cho mỗi chữ ký trong khối **Produces** chưa tồn tại, thân `panic("not implemented")`;
   - type, entity, hoặc proto mới (`make gen-proto` trong `gm-core`) nếu test cần đến.
5. Kiểm tra red:
   - unit: chạy, mỗi test phải FAIL **vì đúng lý do** (assertion sai hoặc `not implemented`), không phải lỗi compile hay setup;
   - integration, e2e: `go vet -tags <tag> ./...` phải sạch. Hỏi người dùng có muốn chạy red trên môi trường nào không; nếu có, chạy qua `scripts/test-report.sh` như mục 4 để có report của lần red; không tự đoán env.
6. Tick bước viết test và bước chạy-cho-fail của mọi task trong plan.
7. Commit trong từng repo có thay đổi: `test(<task-name>): add failing tests`.

## 2. Chốt và khóa

Trình người dùng:
- danh sách file test theo loại, mỗi test một dòng: nó ghim hành vi gì;
- output FAIL rút gọn của từng task, và loại nào chưa chạy red;
- chỗ nào bạn tự quyết thay vì lấy từ plan.

Chờ người dùng chốt. Sửa theo góp ý của họ, trình lại nếu thay đổi đáng kể.

Khi đã chốt, ghi `worktrees/<task-name>/.tests-lock`, mỗi dòng một đường dẫn tính từ `worktrees/<task-name>/`:
- mọi file `*_test.go` bạn đã tạo hoặc sửa (`gm-order/internal/repository/order_test.go`);
- thư mục fixture test dùng, kết thúc bằng `/` (`gm-order/internal/repository/testdata/`) — khóa mọi file bên trong.

Từ đây hook `.claude/hooks/guard-locked-tests.sh` buộc mọi lần sửa file trong lock, và chính file lock, phải qua người dùng duyệt.

## 3. Trong lúc implement

- Không sửa, xóa, đổi tên, hay `t.Skip` test đã khóa. Không viết code nhận diện giá trị của test để lách nó.
- Nếu một test đã khóa có vẻ sai (mâu thuẫn plan, design, hoặc chính nó), dừng lại và trình trong chat: test nào, vì sao sai (trích plan/design), diff đề xuất. Chỉ sửa sau khi người dùng đồng ý; hook sẽ hỏi lại họ lần nữa.
- Được thêm test mới ngoài lock; báo lại khi thêm.
- Xong mỗi task: chạy unit test của task đó, phải PASS, rồi mới tick và commit. Integration, e2e của task chạy khi người dùng cho env.

## 4. Verify cuối

Trước khi chạy integration hoặc e2e, hỏi người dùng lần này chạy ở mode nào (dev, local, ...) và lấy env từ họ. Không đoán, không dùng lại env của lần trước nếu họ chưa nói.

**Bằng chứng:** integration và e2e luôn chạy qua `scripts/test-report.sh <task-name> <integration|e2e> <mode>`, với env người dùng đưa được export trước. Script tự chạy test và ghi report vào `reports/<task-name>/<thời-gian>-<level>-<mode>.md` (env có secret bị che, commit của từng repo, output đầy đủ, exit code). Không chạy `go test -tags integration|e2e` trần khi verify, và không tự viết hay sửa file trong `reports/`; hook chặn việc đó.

Trong mỗi repo của task:

1. `go test ./...` — phải PASS.
2. `scripts/test-report.sh <task-name> integration <mode>` — phải PASS.
3. Nếu task có e2e: `scripts/test-report.sh <task-name> e2e <mode>` — phải PASS.
4. `git diff <commit test(<task-name>)> HEAD -- <các đường dẫn trong lock thuộc repo đó>` — phải rỗng, trừ những thay đổi người dùng đã duyệt.

Commit hết trước bước 2, để commit ghi trong report đúng là code được test (cột "File chưa commit" phải là 0).

Báo nguyên kết quả từng bước, kể cả khi fail, kèm đường dẫn từng report, và nói rõ bước nào chưa chạy vì chưa có env. Không báo xong khi còn test fail hoặc còn loại test chưa chạy.
