# CLAUDE.md

File này hướng dẫn Claude Code (claude.ai/code) khi làm việc với code trong workspace này.

## Workspace này là gì

`go-microservice/` **không** phải một repo duy nhất. Đây là workspace gồm các thư mục ngang hàng, mỗi thư mục là một git repo, một Go module và một remote GitHub riêng dưới `github.com/dangngochoainam/`. Không có `go.mod` ở root, không có git repo ở root, không có build ở mức workspace.

| Thư mục | Module / vai trò | Trạng thái |
|---|---|---|
| `gopkg/` | `github.com/dangngochoainam/gopkg` — thư viện helper dùng chung cho mọi service | đã có code, đã có commit |
| `gm-core/` | `github.com/dangngochoainam/gm-core` — contract protobuf dùng chung: mọi file `.proto` và package Go sinh ra cho mọi service | đã có code (library, không phải service) |
| `gm-gateway/` | Ingress HTTP duy nhất: grpc-gateway fan-out xuống các domain service qua gRPC | đã có code |
| `gm-product/` | Domain service đầu tiên, chỉ gRPC. **Bản tham chiếu** khi dựng domain service mới | đã có code |
| `gm-order/`, `gm-payment/`, `gm-inventory/` | Domain service, chỉ gRPC | repo rỗng |
| `gm-auth/`, `gm-entity/` | repo rỗng, vai trò chưa chốt | repo rỗng |
| `gm-web/` | Frontend | repo rỗng |

Chỉ `gopkg` đã có commit; các repo còn lại có remote và nhánh `main` chưa sinh commit nào. Repo rỗng là scaffold: dựng domain service mới thì copy `gm-product`, dựng ingress thì copy `gm-gateway`, rồi cắt bớt phần không dùng.

## Kiến trúc mục tiêu

Mọi HTTP từ bên ngoài kết thúc tại `gm-gateway`. Gateway dịch REST sang gRPC qua grpc-gateway rồi forward xuống domain service sở hữu nghiệp vụ đó. Traffic giữa các service chỉ đi bằng gRPC, không bao giờ bằng HTTP.

```
browser / client ──HTTP──> gm-gateway ──gRPC──> gm-product / gm-order / gm-payment / gm-inventory / gm-core
                                          └────gRPC────┘  (service ↔ service)
```

**Domain service không mở cửa HTTP public.** Hình dạng bắt buộc, `gm-product` là bản tham chiếu: **traffic nghiệp vụ trên gRPC, cộng một admin listener** mang `/healthz`, `/readyz` và `/metrics` cho kubelet và Prometheus, không bao giờ route qua ingress. Không grpc-gateway mux in-process, không CORS wrapper, không self-dial qua loopback. Các lời gọi `Register<Service>ServiceHandler` chỉ nằm ở repo gateway, mỗi downstream service một lời gọi.

Lý do: một cửa HTTP thứ hai vào domain service sẽ đi vòng qua mọi middleware của gateway, trong đó có allowlist header giữ cho client không tự giả mạo trace ID của mình — thứ mà các service đang tin từ gRPC metadata. `gm-product/docs/service-ports.md` ghi đầy đủ lý do và thứ tự shutdown đi kèm; đọc và copy cả hai khi dựng `gm-order`, `gm-payment` hay `gm-inventory`.

Hệ quả cho file `.proto`: annotation `google.api.http` chỉ có ý nghĩa với process nào chạy gateway mux. Giữ annotation trên service proto để gateway sinh route từ đó, và chia sẻ các package Go sinh ra trong `gm-core/application/` giữa gateway và service sở hữu. Việc chia sẻ đó chính là lý do `gm-core` tồn tại — xem bên dưới.

## Quy tắc xuyên repo

**`gopkg` được dùng theo path, không theo version.** Mọi `go.mod` của service đều có `replace github.com/dangngochoainam/gopkg => ../gopkg`. Hệ quả:

- Một thay đổi trong `gopkg` chỉ thấy được ở service sau khi chạy `go mod tidy && go mod vendor` trong service đó (`make mod`).
- Các service vendor dependency (`vendor/` bị gitignore nhưng phải tồn tại thì mới build được).
- Docker dev container phải bind-mount `../gopkg`; `gm-product/docker-compose.debug.yaml` mount nó tại `/gopkg` để replace `../gopkg` vẫn resolve được từ `/app`.
- Trước khi thêm helper vào một service, đọc `gopkg/README.md` — logging, gRPC middleware, HTTP client có retry, RabbitMQ, Redis, Mongo, GORM, JWT, cursor pagination, copy struct và response envelope đều đã có sẵn ở đó. Code cross-cutting mới thuộc về `gopkg`, không thuộc về service.

**`gm-core` sở hữu mọi file `.proto` và mọi package Go sinh ra từ chúng.** Không service nào tự định nghĩa hay tự generate code protobuf. Cách dùng theo path giống hệt `gopkg`: `replace github.com/dangngochoainam/gm-core => ../gm-core`, và dev container bind-mount `../gm-core:/gm-core`.

Mỗi service một thư mục cho mỗi version, chia thành `dto` và `service`, và đường dẫn thư mục trùng với proto package:

```
gm-core/proto/product/v1/dto/product.dto.proto          package product.v1.dto       messages
gm-core/proto/product/v1/service/product.service.proto  package product.v1.service   service ProductService
gm-core/third_party/                                    vendored google/api + buf/validate, never generated
gm-core/application/product/v1/dto/                     generated Go, imported as productdtov1
gm-core/application/product/v1/service/                 generated Go, imported as productsvcv1
```

`dto` và `service` là hai proto package tách rời một cách có chủ đích: hai file trong cùng một proto package buộc phải chung `go_package`, nên không cách nào khác cho ra hai Go package thật sự. Caller chỉ dựng message thì import `dto` mà không kéo theo gRPC runtime.

Một thay đổi breaking sẽ mở `proto/product/v2/` bên cạnh `v1`; cả hai đều generate, nên các service migrate độc lập. Chi tiết và bảng đặt tên đầy đủ nằm trong `gm-core/CLAUDE.md`.

**Mỗi repo có CLAUDE.md riêng.** `gm-product/CLAUDE.md` giữ quy tắc layer/DI/converter cho domain service, `gm-gateway/CLAUDE.md` cho ingress, `gm-core/CLAUDE.md` cho contract protobuf, `gopkg/CLAUDE.md` cho package helper. Đọc file của repo đang sửa thay vì nhân bản quy tắc của nó vào đây.

## Toolchain

Mọi module đều khai báo **go 1.24.0**, không module nào có dòng `toolchain`, và dev container là `golang:1.24-alpine`. Giữ dòng `go` đồng bộ giữa `gopkg/go.mod`, `gm-core/go.mod`, `gm-gateway/go.mod`, `gm-product/go.mod` và `gm-product/db/golang-migrate/loader/go.mod`.

Binary tại `/usr/local/go` vẫn là 1.23.0, nhưng `GOTOOLCHAIN` là `auto` nên Go tự tải và chạy toolchain mà module yêu cầu. `go build` và `go test` phía host chạy bình thường; `go version` báo 1.23.0 khi ở ngoài module và 1.24.0 khi ở trong module. Đây là hành vi đúng, không phải lỗi cấu hình.

**Codegen là việc chạy phía host, và chỉ diễn ra trong `gm-core`.** Máy chỉ cần có Go, không cài thêm gì: `buf` và ba code generator được pin bằng tool directive trong `gm-core/tools/go.mod`, và `make gen-proto` tự build chúng vào `gm-core/bin/` nếu còn thiếu. Không chỗ nào cần protoc, và sau lần bootstrap đầu tiên thì generate không cần mạng. Dev image của service (`gm-product/Dockerfile.debug`, `gm-gateway/Dockerfile.debug`) chỉ mang thứ để chạy và debug service: Atlas, Delve, CompileDaemon. Không service nào có target `gen-proto`, vì không bao giờ generate gì vào repo service.

## Lệnh

Chạy các lệnh này từ bên trong repo tương ứng.

```bash
# mọi repo Go (gopkg, gm-core, gm-gateway, gm-product)
make fmt          # sửa format: gofmt + goimports
make lint         # golangci-lint v2.14.0, config ở .golangci.yml — chỉ chặn lỗi mới so với origin/master
make build        # go build ./...
make verify       # lint + build, không chạy test
make test         # go test ./... — unit test, không tag

# gopkg
make test-pkg PKG=loghelper    # một package
go test ./loghelper/... -run TestName

# một service (gm-product, gm-gateway, và mọi thứ derive từ chúng)
make start        # docker compose up container debug
make attach       # vào shell của container; mọi lệnh dưới đây chạy bên trong
make mod          # go mod tidy && go mod vendor  — sau mỗi thay đổi ở gopkg, gm-core hoặc go.mod
make run          # go run ./cmd/server/main.go
make run-watch    # CompileDaemon rebuild + Delve trên :2302

# gm-core (contract protobuf dùng chung)
make tools        # build bin/buf + 3 plugin từ tools/ — gen-proto tự gọi nếu thiếu
make gen-proto    # buf generate proto -> application/<service>/v<n>/{dto,service}/
make mod          # go mod tidy
```

Lỗi lint có sẵn từ trước khi thêm lint được ghi trong `NOTES.md` của từng repo. golangci-lint cần go >= 1.26 nên chạy qua `go run ...@v2.14.0`; `GOTOOLCHAIN=auto` tự tải go1.26 chỉ để build linter, các module vẫn giữ `go 1.24.0`.

`make start` cần một Docker network external tên `docker_stack` có PostgreSQL truy cập được qua host `postgres:5432`. Tạo bằng `docker network create docker_stack` nếu chưa có.

Map port phía host:

| Container | Host → trong container | Ghi chú |
|---|---|---|
| `gm-product` | `50060` → `50050` (gRPC), `2302` → `2302` (Delve) | admin port `50051` cố ý không publish — probe và `/metrics` chỉ gọi từ bên trong, qua `make attach` |
| `gm-gateway` | `50061` → `50051` (HTTP public), `2302` → `2302` (Delve) | cửa HTTP duy nhất ra ngoài |

Hai container cùng map Delve `2302`, nên chỉ chạy debug một service tại một thời điểm, hoặc đổi port phía host trước khi `make start` cả hai.

## Quy trình proto

Mọi bước dưới đây diễn ra trong `gm-core`, bất kể bạn bắt đầu từ repo nào.

1. Sửa `gm-core/proto/<service>/v<n>/dto/<service>.dto.proto` (message) hoặc `service/<service>.service.proto` (rpc).
2. `make gen-proto` trong `gm-core`, chạy trên host. Không nơi nào khác có target này.
3. Commit phần `gm-core/application/` vừa regenerate cùng với thay đổi `.proto` — code sinh ra được commit vào repo.
4. `make mod` trong mọi service tiêu thụ để bản vendor bắt kịp.
5. Cập nhật handler trong `internal/api/` của service đó, và lời gọi `Register<Service>ServiceHandler` trong `gm-gateway/cmd/server/main.go` nếu route có thay đổi.

`gm-core` generate bằng `buf`, không phải protoc, và là repo duy nhất generate bất cứ thứ gì. Dev image của service không mang công cụ codegen nào, nên hãy chạy `make gen-proto` từ shell host trong `gm-core`, rồi `make mod` trong từng service tiêu thụ. Xem `gm-core/NOTES.md` để biết những gì còn đang hoãn, trong đó có bước CI kiểm tra rằng `application/` đã commit thực sự khớp với proto.

## Quy trình database

Chỉ service nào có database mới có thư mục `db/`; hiện tại là `gm-product`. Gateway stateless, không bao giờ mở connection. Đường dẫn dưới đây tính từ gốc repo service.

Schema sinh ra từ struct entity của GORM, không viết SQL tay. Atlas diff entity với database đang chạy.

1. Sửa hoặc thêm struct trong `db/entities/`.
2. Đăng ký entity mới trong `db/golang-migrate/loader/main.go`.
3. `cd db/golang-migrate && ./shmake build` (build lại binary loader — bắt buộc sau khi đổi entity).
4. `./shmake diff <migration_name>` rồi review `migrations/`.
5. `./shmake apply`.

`db/golang-migrate/loader/` là một **Go module riêng**, tách khỏi service. Credential lấy từ `export-env.local.sh`, file này không commit.

Lỗi đã biết ở `gm-product`: `db/golang-migrate/loader/main.go` đăng ký `entities.Job`, nhưng `db/entities/` chỉ định nghĩa `Product` và `BaseModel`, nên `./shmake build` không compile được. Hoặc thêm entity còn thiếu, hoặc bỏ tham chiếu đó trước khi chạy migration.

## Cấu hình

Config là một khối YAML nhúng trong `configs/config.go` làm giá trị mặc định, ghi đè bằng biến môi trường qua Viper. Key lồng nhau dùng `__` làm dấu phân cách: `database_postgres.host` tương ứng `DATABASE_POSTGRES__HOST`. Copy `.env.example` thành `.env` cho từng service — bắt buộc, không phải tùy chọn: default trong `gm-product/configs/config.go` đang ghi số port phía host (`grpc_port: 50060`), còn port thật trong container là `50050` và chỉ đến từ `.env`.
