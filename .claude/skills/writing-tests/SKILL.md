---
name: writing-tests
description: Use right after a plan in plans/<task-name>/plan.md is approved and before implementing it - write test scenarios (happy, edge, boundary, error handling) into plans/<task-name>/tests.md, implement them as failing unit/integration/e2e tests, get them approved, and lock them. Also use whenever a locked test looks wrong during implementation.
---

# Writing Tests

Kịch bản test viết trước, hiện thực thành test, người dùng chốt, rồi khóa. Sau đó test là thước đo cố định để tự verify phần implement: code phải theo test, không phải test theo code.

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

## 1. Viết kịch bản

Kịch bản là thứ người dùng đọc và chốt; code test chỉ hiện thực nó. Mọi kịch bản của task nằm trong **một file duy nhất** `plans/<task-name>/tests.md`, gồm cả unit, integration và e2e.

1. Đọc plan `plans/<task-name>/plan.md` và design doc nó trỏ tới (`plans/<task-name>/design.md`).
2. Với mỗi task trong plan, viết kịch bản cho đủ bốn nhóm:

   | Nhóm | Mã | Câu hỏi phải trả lời |
   |---|---|---|
   | Happy case | `HP` | Input hợp lệ, điển hình: kết quả đúng như design? |
   | Edge case | `EC` | Input hợp lệ nhưng bất thường: rỗng, nil, trùng, unicode, đúng một phần tử, gọi lặp lại, lỗi bị bọc nhiều tầng? |
   | Case biên | `BD` | Ngay tại giới hạn và vượt giới hạn một đơn vị: min, min−1, max, max+1, độ dài tối đa, page cuối? |
   | Xử lý lỗi | `ER` | Input sai, dependency lỗi (DB, service khác, timeout, panic): code/message/status trả ra là gì, và không lộ gì? |

   - Lấy từ plan trước: bước "Write the failing test", bảng tiêu chí xong và các dòng Review Focus.
   - Rồi tự soát từng nhóm cho mỗi task và thêm kịch bản plan còn thiếu, ghi `(ngoài plan)` ở cột Mã.
   - Nhóm nào không áp dụng cho một task thì ghi một dòng `không áp dụng` kèm lý do, không bỏ trống. Bỏ trống thì người duyệt không biết là đã soát hay quên.
   - Mỗi kịch bản chọn loại test rẻ nhất mà vẫn chứng minh được nó: unit trước, integration khi cần hạ tầng thật, e2e khi cần đi qua gateway. Kịch bản phải tắt hạ tầng giữa chừng mà không tự động hóa tin cậy được thì đưa vào mục "Kiểm tra tay".
   - Kỳ vọng ghi giá trị chính xác (code, status, message, field), không ghi "báo lỗi phù hợp".
3. Ghi vào `tests.md` theo mẫu ở mục "File kịch bản", trạng thái `chưa viết`.

## 2. Hiện thực thành test

1. Tạo worktree: `scripts/task-start.sh <task-name> <Repos trong plan>`. Mọi file dưới đây nằm trong `worktrees/<task-name>/`.
2. Mỗi kịch bản một test Go (hoặc một case trong test table-driven), đúng loại và đúng giá trị kịch bản ghi. Code test nằm trong repo, cạnh package nó test, vì Go không compile được test ở chỗ khác. Điền cột "Hiện thực".
3. Thêm vừa đủ để test compile, không viết logic:
   - stub cho mỗi chữ ký trong khối **Produces** chưa tồn tại, thân `panic("not implemented")`;
   - type, entity, hoặc proto mới (`make gen-proto` trong `gm-core`) nếu test cần đến.
4. Kiểm tra red:
   - unit: chạy, mỗi test phải FAIL **vì đúng lý do** (assertion sai hoặc `not implemented`), không phải lỗi compile hay setup. Test ghim hành vi đã có sẵn thì PASS ngay là đúng; ghi rõ trong cột Trạng thái;
   - integration, e2e: `go vet -tags <tag> ./...` phải sạch. Hỏi người dùng có muốn chạy red trên môi trường nào không; nếu có, chạy qua `scripts/test-report.sh` như mục 5 để có report của lần red; không tự đoán env.
5. Cập nhật trạng thái trong `tests.md`.
6. Tick bước viết test và bước chạy-cho-fail của mọi task trong plan. Kịch bản `(ngoài plan)` thì thêm vào bước test của task tương ứng trong plan.
7. Commit trong từng repo có thay đổi, khi người dùng cho phép (`git.md`): `test(<task-name>): add failing tests`.

## File kịch bản

```markdown
# Kịch bản test — <task-name>

Khóa: chưa | rồi (<ngày>)

## Cách chạy

| Loại | Hạ tầng | Env (thiếu thì t.Fatal) | Lệnh |
|---|---|---|---|
| unit | không | — | `go test ./...` trong từng repo |
| integration | <PostgreSQL trên docker_stack, …> | <DATABASE_POSTGRES__HOST, …> | `scripts/test-report.sh <task-name> integration <mode>` |
| e2e | <service nào chạy, dữ liệu nào phải có> | `E2E_GATEWAY_URL` | `scripts/test-report.sh <task-name> e2e <mode>` |

Chỉ giữ dòng của loại task thật sự có.

## Task 1 — <tên task trong plan>

| Mã | Loại | Bối cảnh | Hành động | Kỳ vọng | Hiện thực | Trạng thái |
|---|---|---|---|---|---|---|
| HP-1.1 | unit | `ErrBadRequest` | `ToStatus(err, "gm-test")` | `InvalidArgument`, `ErrorInfo{BAD_REQUEST, gm-test}` | `gopkg/…/error_test.go` `TestToStatusSentinels` | red |
| EC-1.1 | unit | sentinel bọc 2 tầng | … | … | … | red |
| BD-1.1 | … | … | … | … | … | … |
| ER-1.1 | … | … | … | … | … | … |

## Kiểm tra tay

| Mã | Bối cảnh | Hành động | Kỳ vọng |
|---|---|---|---|

## Report
- <đường dẫn reports/<task-name>/… của từng lần chạy, kèm loại, mode và PASS/FAIL>
```

- Trong mỗi task, sắp kịch bản theo nhóm: HP, EC, BD, ER.
- Đường dẫn ở cột "Hiện thực" tính từ `worktrees/<task-name>/`.
- Trạng thái: `chưa viết`, `red` (đã chạy, fail đúng lý do), `chưa chạy` (integration/e2e chưa có env), `green`. Cập nhật mỗi khi trạng thái đổi, khi khóa, khi thêm kịch bản ngoài lock, và khi có report mới.

## 3. Chốt và khóa

Trình người dùng:
- `plans/<task-name>/tests.md`, nói rõ số kịch bản mỗi nhóm và các kịch bản `(ngoài plan)`;
- output FAIL rút gọn của từng task, và loại nào chưa chạy red;
- chỗ nào bạn tự quyết thay vì lấy từ plan.

Chờ người dùng chốt. Sửa theo góp ý của họ, trình lại nếu thay đổi đáng kể.

Khi đã chốt, ghi `worktrees/<task-name>/.tests-lock`, mỗi dòng một đường dẫn tính từ `worktrees/<task-name>/`:
- mọi file `*_test.go` bạn đã tạo hoặc sửa (`gm-order/internal/repository/order_test.go`);
- thư mục fixture test dùng, kết thúc bằng `/` (`gm-order/internal/repository/testdata/`) — khóa mọi file bên trong.

Đặt `Khóa: rồi (<ngày>)` trong `tests.md`.

Từ đây hook `.claude/hooks/guard-locked-tests.sh` buộc mọi lần sửa file trong lock, và chính file lock, phải qua người dùng duyệt.

## 4. Trong lúc implement

- Không sửa, xóa, đổi tên, hay `t.Skip` test đã khóa. Không viết code nhận diện giá trị của test để lách nó.
- Nếu một test đã khóa có vẻ sai (mâu thuẫn plan, design, hoặc chính nó), dừng lại và trình trong chat: test nào, vì sao sai (trích plan/design), diff đề xuất. Chỉ sửa sau khi người dùng đồng ý; hook sẽ hỏi lại họ lần nữa.
- Được thêm test mới ngoài lock; báo lại khi thêm và thêm kịch bản vào `tests.md`, ghi `(ngoài lock)` ở cột Mã.
- Xong mỗi task: chạy unit test của task đó, phải PASS, đổi trạng thái các kịch bản unit của task trong `tests.md` sang `green`, rồi mới tick và commit. Integration, e2e của task chạy khi người dùng cho env.

## 5. Verify cuối

Trước khi chạy integration hoặc e2e, hỏi người dùng lần này chạy ở mode nào (dev, local, ...) và lấy env từ họ. Không đoán, không dùng lại env của lần trước nếu họ chưa nói.

**Bằng chứng:** integration và e2e luôn chạy qua `scripts/test-report.sh <task-name> <integration|e2e> <mode>`, với env người dùng đưa được export trước. Script tự chạy test và ghi report vào `reports/<task-name>/<thời-gian>-<level>-<mode>.md` (env có secret bị che, commit của từng repo, output đầy đủ, exit code). Không chạy `go test -tags integration|e2e` trần khi verify, và không tự viết hay sửa file trong `reports/`; hook chặn việc đó.

Trong mỗi repo của task:

1. `go test ./...` — phải PASS.
2. `scripts/test-report.sh <task-name> integration <mode>` — phải PASS.
3. Nếu task có e2e: `scripts/test-report.sh <task-name> e2e <mode>` — phải PASS.
4. `git diff <commit test(<task-name>)> HEAD -- <các đường dẫn trong lock thuộc repo đó>` — phải rỗng, trừ những thay đổi người dùng đã duyệt.

Commit hết trước bước 2, để commit ghi trong report đúng là code được test (cột "File chưa commit" phải là 0).

Ghi đường dẫn report vào mục Report của `tests.md` và cập nhật trạng thái. Báo nguyên kết quả từng bước, kể cả khi fail, kèm đường dẫn từng report, và nói rõ bước nào chưa chạy vì chưa có env. Không báo xong khi còn test fail hoặc còn loại test chưa chạy.
