# Setup Kong bằng Docker

### Bước 1: Cài đặt Kong

1. Nếu bạn đã cài đặt Kong bằng Docker, hãy chắc chắn rằng bạn đã thiết lập một network để liên kết Kong với các dịch vụ khác
   ```bash
   docker network create kong-net
   ```

2. Khởi chạy một container Postgres cho cơ sở dữ liệu của Kong:
   ```bash
   docker run -d --name kong-database \
     --network=kong-net \
     -p 5432:5432 \
     -e "POSTGRES_USER=kong" \
     -e "POSTGRES_DB=kong" \
     -e "POSTGRES_PASSWORD=kong" \
     postgres:13
   ```

3. Khởi tạo cơ sở dữ liệu cho Kong:
   ```bash
   docker run --rm \
     --network=kong-net \
     -e "KONG_DATABASE=postgres" \
     -e "KONG_PG_HOST=kong-database" \
     -e "KONG_PG_PASSWORD=kong" \
     kong/kong-gateway:latest kong migrations bootstrap
   ```

4. Chạy Kong:
   ```bash
   docker run -d --name kong \
     --network=kong-net \
     -e "KONG_DATABASE=postgres" \
     -e "KONG_PG_HOST=postgresql" \
     -e "KONG_PG_PASSWORD=postgres" \
     -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
     -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
     -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
     -p 8000:8000 \
     -p 8001:8001 \
     kong/kong-gateway:latest
   ```

# Setup Kong thuộc service của Docker-Compose

### Bước 1: Cập nhật `docker-compose.yml`

Trong file `docker-compose.yml`, thêm các service như sau:

```yaml
version: '3.8'

services:
  postgresql:
    image: postgres:13
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
      POSTGRES_PASSWORD: postgres
    networks:
      - kong-net

  gateway:
    # gateway-service config
    networks:
      - kong-net

  book-service:
    # grpc-service config
    networks:
      - kong-net

  kong:
    image: kong/kong-gateway:latest
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: postgresql
      KONG_PG_PASSWORD: postgres
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    depends_on:
      - postgresql
    networks:
      - kong-net
    ports:
      - "8000:8000"  # cổng proxy
      - "8001:8001"  # cổng admin

networks:
  kong-net:
    driver: bridge
```

### Bước 2: Khởi tạo Database cho Kong (Thực hiện thủ công một lần)

Chạy lệnh sau để khởi tạo cơ sở dữ liệu cho Kong. Lệnh này chỉ cần chạy một lần và sẽ thực hiện sau khi khởi động các service trong `docker-compose.yml`

```bash
docker-compose run --rm kong kong migrations bootstrap
```

Sau khi lệnh này hoàn tất, bạn có thể khởi động lại toàn bộ dịch vụ bằng lệnh:

```bash
docker-compose up -d
```

# Cấu hình các Service và Route trong Kong

1. **Tạo Service** trong Kong cho từng dịch vụ backend (gRPC gateway endpoint)

   Ví dụ: nếu bạn có một dịch vụ `BookService` và `grpc-gateway` đã tạo các endpoint HTTP tại `http://<grpc-gateway>:8080`, bạn có thể cấu hình như sau:

   ```bash
   curl -i -X POST http://localhost:8001/services \
     --data "name=book-service" \
     --data "url=http://<grpc-gateway>:8080"
   ```
   Lấy danh sách các service đã tạo:

   ```bash
   curl -i -X GET http://localhost:8001/services
   ```

2. **Tạo Route** để xác định đường dẫn cho từng endpoint HTTP mà bạn muốn nhận từ Kong.

   ```bash
   curl -i -X POST http://localhost:8001/services/book-service/routes \
     --data "paths[]=/book" \
     --data "strip_path=false"
   ```

   Thao tác này sẽ cấu hình một route `/book` trong Kong. Khi có một request đến `http://kong-host:8000/book`, Kong sẽ chuyển tiếp tới `http://<grpc-gateway>:8080/book`

   Lấy danh sách các routes của 1 service cụ thể:

   ```bash
   curl -i -X GET http://localhost:8001/services/${SERVICE_NAME}/routes
   ```

3. **Tùy chỉnh các route** để xác định các endpoint cụ thể nếu bạn có nhiều phương thức trong `BookService` (như `Create`, `GetBook`, `ListBooks`)

   Ví dụ: để định tuyến `GET /book/{id}` tới `grpc-gateway`:
   ```bash
   curl -i -X POST http://localhost:8001/services/book-service/routes \
     --data "paths[]=/book/{id}" \
     --data "methods[]=GET"
   ```

4. Xóa route theo ID

   ```bash
   curl -i -X DELETE http://localhost:8001/routes/${ROUTE_ID}
   ```

# Cấu hình các Plugin (Tùy chọn) 

Kong có nhiều plugin có thể giúp bạn bảo mật và giám sát truy cập 
Một số plugin hữu ích bao gồm:

- **Rate Limiting**: Để hạn chế lưu lượng truy cập đến các dịch vụ
- **Authentication**: Áp dụng OAuth2, API key, hoặc Basic Auth để kiểm soát quyền truy cập
- **Logging**: Để ghi lại thông tin truy cập và giúp kiểm soát chất lượng dịch vụ

Ví dụ để cài đặt plugin `Rate Limiting`:
```bash
curl -i -X POST http://localhost:8001/services/book-service/plugins \
  --data "name=rate-limiting" \
  --data "config.second=5"
```

# Sử dụng kong.yml để config các service và route

File `kong.yml` không bắt buộc để khởi động và cấu hình cơ bản cho Kong
nhưng có thể hữu ích nếu bạn muốn quản lý cấu hình Kong một cách dễ dàng hơn
đặc biệt khi bạn muốn tự động hoá việc tạo các **Service**, **Route**, và **Plugin** trên Kong

`kong.yml` là một file cấu hình có thể được dùng với công cụ **decK** (một công cụ CLI quản lý cấu hình Kong)
Với `kong.yml`, bạn có thể định nghĩa tất cả các service, route, và plugin của Kong trong một file duy nhất, sau đó áp dụng chúng chỉ bằng một lệnh

### Khi nào nên dùng `kong.yml`?

1. **Quản lý cấu hình dễ dàng hơn**: Thay vì dùng các lệnh `curl` thủ công để tạo từng service và route, bạn có thể quản lý tất cả cấu hình trong một file `kong.yml`
2. **Tự động hóa và kiểm soát phiên bản**: Nếu bạn có nhiều cấu hình và muốn kiểm soát phiên bản hoặc dễ dàng triển khai lại cấu hình khi có thay đổi, `kong.yml` rất hữu ích
3. **Di chuyển và sao lưu**: File này giúp bạn dễ dàng di chuyển cấu hình Kong giữa các môi trường (dev, staging, production)

### Cách dùng `kong.yml` với decK

1. **Cài đặt decK** (nếu chưa có):
   ```bash
   curl -L https://github.com/kong/deck/releases/download/v1.7.0/deck_1.7.0_linux_amd64.tar.gz | tar xvz
   sudo mv deck /usr/local/bin/
   ```

2. **Tạo file `kong.yml`** với nội dung mẫu:
   ```yaml
   _format_version: "1.1"
   services:
     - name: book-service
       url: http://gateway:8080
       routes:
         - name: book-route
           paths:
             - /book
   ```

3. **Áp dụng file `kong.yml`** bằng lệnh:
   ```bash
   deck sync --konnect-host=http://localhost:8001 --konnect-token=<Kong_admin_token>
   ```

### kong.yml config for book-service

```yaml
_format_version: "1.1"
services:
  - name: book-service
    url: http://gateway:8080  # URL của gateway đang proxy đến các endpoint gRPC được sinh bởi grpc-gateway
    routes:
      - name: create-book-route
        paths:
          - /v1/books
        methods:
          - POST
      - name: list-books-route
        paths:
          - /v1/books
        methods:
          - GET
      - name: get-book-route
        paths:
          - /v1/books/{book_id}
        methods:
          - GET
```

### Giải thích cấu hình

- **Service** `book-service`:
  - URL của service trỏ tới `http://gateway:8080`, đây là nơi `grpc-gateway` đang lắng nghe để chuyển tiếp request tới các phương thức gRPC trong `book-service`

- **Routes**:
  - `create-book-route`: Định nghĩa đường dẫn `/v1/books` với phương thức `POST` để tạo một cuốn sách
  - `list-books-route`: Định nghĩa đường dẫn `/v1/books` với phương thức `GET` để lấy danh sách sách
  - `get-book-route`: Định nghĩa đường dẫn `/v1/books/{book_id}` với phương thức `GET` để lấy thông tin của một cuốn sách cụ thể

### Áp dụng cấu hình với decK

Sau khi tạo file `kong.yml`, bạn có thể dùng lệnh sau để áp dụng cấu hình:

```bash
deck sync --kong-addr http://localhost:8001
```
