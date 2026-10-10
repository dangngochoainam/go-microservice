# Tự verify code

Mọi repo Go có các target sau, chạy trong `worktrees/<task>/<repo>/`:

| Lệnh | Làm gì |
|---|---|
| `make fmt` | sửa format (gofmt, goimports) |
| `make lint` | golangci-lint, config ở `.golangci.yml` của repo |
| `make build` | `go build ./...` |
| `make test` | unit test, `go test ./...` (không tag) |
| `make verify` | lint + build (không chạy test) |

`scripts/verify.sh <task> [repo...]` chạy `make verify` cho các repo của task (mặc định là tất cả).

## Khi nào chạy

- Xong mỗi task trong plan: `make verify` ở các repo task đó đụng tới, PASS rồi mới tick; commit chỉ khi người dùng cho phép (xem `git.md`).
- Trước khi báo xong với người dùng: `scripts/verify.sh <task>`.
- Test (unit, integration, e2e) không nằm trong verify: chạy ở bước sau, trong một session khác, theo skill `writing-tests`.

## Hook

- Mỗi lần Edit/Write file `.go` trong `worktrees/`, hook tự `gofmt -w` file đó; lỗi cú pháp được báo lại ngay.
- Khi kết thúc lượt, hook Stop chạy `scripts/verify.sh` cho mọi repo trong `worktrees/` đã đổi kể từ lần PASS gần nhất. Fail thì không được kết thúc, phải sửa tiếp (tối đa 3 lần liên tiếp, sau đó dừng và báo người dùng).

## Không được

- Thêm `//nolint`, nới `.golangci.yml`, hay bỏ target khỏi `verify` để cho PASS mà chưa hỏi người dùng.
- Sửa lỗi lint có sẵn từ trước ở code task không đụng tới; báo lại thay vì tự sửa.
