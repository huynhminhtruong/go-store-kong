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
     -e "KONG_PG_HOST=kong-database" \
     -e "KONG_PG_PASSWORD=kong" \
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
      POSTGRES_USER: kong
      POSTGRES_DB: kong
      POSTGRES_PASSWORD: kong
    networks:
      - kong-net

  gateway:
    # cấu hình của gateway của bạn để đăng ký các endpoint cho gRPC services
    networks:
      - kong-net

  book-service:
    # cấu hình của dịch vụ book-service (gRPC service của bạn)
    networks:
      - kong-net

  kong:
    image: kong/kong-gateway:latest
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: postgresql
      KONG_PG_PASSWORD: kong
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

2. **Tạo Route** để xác định đường dẫn cho từng endpoint HTTP mà bạn muốn nhận từ Kong.

   ```bash
   curl -i -X POST http://localhost:8001/services/book-service/routes \
     --data "paths[]=/book" \
     --data "strip_path=false"
   ```

   Thao tác này sẽ cấu hình một route `/book` trong Kong. Khi có một request đến `http://kong-host:8000/book`, Kong sẽ chuyển tiếp tới `http://<grpc-gateway>:8080/book`

3. **Tùy chỉnh các route** để xác định các endpoint cụ thể nếu bạn có nhiều phương thức trong `BookService` (như `Create`, `GetBook`, `ListBooks`)

   Ví dụ: để định tuyến `GET /book/{id}` tới `grpc-gateway`:
   ```bash
   curl -i -X POST http://localhost:8001/services/book-service/routes \
     --data "paths[]=/book/{id}" \
     --data "methods[]=GET"
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
