# go-store-kong

Để triển khai một hệ thống microservice sử dụng Kong làm gateway để chuyển các yêu cầu HTTP đến các gRPC services được triển khai bằng Golang và Docker, bạn có thể làm theo các bước sau:

### 1. **Cấu trúc dự án và dịch vụ**

- Tạo các service con dưới dạng Docker container. Mỗi service sẽ được đóng gói và chạy độc lập
- Sử dụng Golang để triển khai các gRPC services, mỗi service sẽ có các chức năng riêng biệt
- Sử dụng Kong làm gateway đặt ở layer trên cùng để nhận các HTTP request và chuyển đổi chúng thành các gRPC call đến các service bên dưới

### 2. **Triển khai gRPC Services với Golang**

- Tạo một module Go cho từng gRPC service. Mỗi service sẽ được định nghĩa trong một file `.proto` và sử dụng `protoc-gen-go` và `protoc-gen-go-grpc` để generate code Go cho các service đó.
- Tạo các handler cho từng gRPC service để xử lý các API chính, ví dụ: `BookService`, `OrderService`.
- Dockerize các gRPC service bằng cách tạo Dockerfile riêng cho mỗi service. Dockerfile cơ bản cho một gRPC service có thể như sau:

  ```dockerfile
  # Dockerfile cho gRPC service
  FROM golang:1.20-alpine
  WORKDIR /app
  COPY . .
  RUN go mod download
  RUN go build -o service main.go
  EXPOSE 50051
  CMD ["./service"]
  ```

- Trong file `main.go` của từng service, bạn cần khởi động gRPC server và chỉ định port để service có thể giao tiếp qua gRPC

### 3. **Triển khai Kong Gateway cho gRPC Services**

- Dùng Kong làm gateway API và triển khai nó dưới dạng một Docker container
- Tạo một Docker Compose để dễ dàng quản lý các container. Đối với Kong, bạn sẽ cần cấu hình để nó có thể lắng nghe các yêu cầu HTTP từ client và chuyển tiếp đến các gRPC services

  ```yaml
  # docker-compose.yml
  version: "3"
  services:
    kong:
      image: kong:latest
      environment:
        KONG_DATABASE: "off"
        KONG_DECLARATIVE_CONFIG: "/kong.yml"
        KONG_PROXY_LISTEN: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
      ports:
        - "8000:8000" # HTTP Port
        - "8443:8443" # HTTPS Port
        - "8001:8001" # Admin API Port (optional)
      volumes:
        - ./kong.yml:/kong.yml
  ```

- Trong file `kong.yml`, cấu hình các route và service. Ví dụ, bạn có thể định nghĩa các service gRPC để Kong có thể gọi đến từng gRPC service

  ```yaml
  _format_version: "2.1"
  services:
    - name: book_service
      url: grpc://book-service:50051
      routes:
        - name: book_route
          paths:
            - /book
          protocols:
            - http
            - https

    - name: order_service
      url: grpc://order-service:50052
      routes:
        - name: order_route
          paths:
            - /order
          protocols:
            - http
            - https
  ```

### 4. **Docker Compose để quản lý toàn bộ hệ thống**

- Sử dụng Docker Compose để đồng thời khởi chạy các container của gRPC services và Kong. Đây là một ví dụ `docker-compose.yml` đầy đủ:

  ```yaml
  version: "3"
  services:
    book-service:
      build:
        context: ./book-service
      ports:
        - "50051:50051"
      networks:
        - kong-net

    order-service:
      build:
        context: ./order-service
      ports:
        - "50052:50052"
      networks:
        - kong-net

    kong:
      image: kong:latest
      environment:
        KONG_DATABASE: "off"
        KONG_DECLARATIVE_CONFIG: "/kong.yml"
        KONG_PROXY_LISTEN: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
      ports:
        - "8000:8000"
        - "8443:8443"
      volumes:
        - ./kong.yml:/kong.yml
      depends_on:
        - book-service
        - order-service
      networks:
        - kong-net

  networks:
    kong-net:
      driver: bridge
  ```

### 5. **Cấu hình và Test**

- Khi tất cả các container được khởi động, Kong sẽ lắng nghe ở cổng `8000` (HTTP) và chuyển tiếp yêu cầu đến các service gRPC thông qua `kong.yml`.
- Test bằng cách gửi HTTP request đến Kong với đường dẫn `/book` hoặc `/order`. Kong sẽ chuyển đổi các request HTTP này thành gRPC request và chuyển tiếp đến `book-service` hoặc `order-service`

### 6. **Triển khai và giám sát**

- Đưa các dịch vụ lên production và đảm bảo giám sát hiệu suất của các gRPC services cũng như Kong Gateway. Sử dụng công cụ như Prometheus hoặc Grafana để theo dõi metric của các container
- Thiết lập Kong Admin API (chạy trên cổng `8001`) để quản lý và giám sát các route và dịch vụ

### Lợi ích của cách triển khai

- **Độc lập và linh hoạt**: Mỗi service hoạt động độc lập và có thể mở rộng linh hoạt
- **Dễ quản lý với Kong**: Gateway Kong chuyển đổi và quản lý traffic một cách dễ dàng và bảo mật
- **Sử dụng Docker Compose**: Đơn giản hóa việc quản lý container và dễ dàng triển khai lại toàn bộ hệ thống nếu cần thiết

Bằng cách làm theo các bước này, bạn sẽ có được một hệ thống microservice sử dụng Kong để quản lý traffic đến các gRPC services viết bằng Golang và được triển khai trên Docker
