# go-store-kong

Để minh họa cách gửi một yêu cầu thông qua Kong đến một gRPC service, hãy xem xét một ví dụ cụ thể với các bước từ việc cấu hình Kong cho đến việc gửi yêu cầu và nhận phản hồi

### **1. Cấu hình dịch vụ gRPC**

Giả sử bạn có một gRPC service đơn giản có tên là `BookService` như sau:

#### **File `book.proto`**

```protobuf
syntax = "proto3";

package book;

service BookService {
    rpc GetBook (GetBookRequest) returns (BookResponse);
}

message GetBookRequest {
    string id = 1;
}

message BookResponse {
    string title = 1;
    string author = 2;
}
```

### **2. Triển khai gRPC Service bằng Go**

#### **File `main.go`**

```go
package main

import (
    "context"
    "log"
    "net"

    pb "path/to/your/proto/package" // Cập nhật đường dẫn đến package của bạn
    "google.golang.org/grpc"
)

type server struct {
    pb.UnimplementedBookServiceServer
}

func (s *server) GetBook(ctx context.Context, req *pb.GetBookRequest) (*pb.BookResponse, error) {
    // Giả lập dữ liệu
    return &pb.BookResponse{
        Title:  "The Great Gatsby",
        Author: "F. Scott Fitzgerald",
    }, nil
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("Failed to listen: %v", err)
    }

    grpcServer := grpc.NewServer()
    pb.RegisterBookServiceServer(grpcServer, &server{})

    log.Println("gRPC server is running on port 50051...")
    if err := grpcServer.Serve(lis); err != nil {
        log.Fatalf("Failed to serve: %v", err)
    }
}
```

### **3. Dockerize gRPC Service**

#### **File `Dockerfile`**

```dockerfile
FROM golang:1.20-alpine

WORKDIR /app
COPY . .
RUN go mod download
RUN go build -o book-service main.go

EXPOSE 50051
CMD ["./book-service"]
```

### **4. Cấu hình Kong Gateway**

#### **File `docker-compose.yml`**

```yaml
version: "3"
services:
  book-service:
    build:
      context: ./path/to/book-service
    ports:
      - "50051:50051"

  kong:
    image: kong:latest
    environment:
      KONG_DATABASE: "off"
      KONG_PROXY_LISTEN: "0.0.0.0:8000"
      KONG_ADMIN_LISTEN: "0.0.0.0:8001"
    ports:
      - "8000:8000" # Port cho HTTP
      - "8443:8443" # HTTPS Port
      - "8001:8001" # Port cho Admin API
    networks:
      - kong-net

networks:
  kong-net:
    driver: bridge
```

### **5. Cấu hình các dịch vụ và route trong Kong**

#### **File `kong.yml`**

```yaml
_format_version: "2.1"
services:
  - name: book_service
    url: grpc://book-service:50051
    routes:
      - name: book_route
        paths:
          - /books
        protocols:
          - http
          - grpc
```

### **6. Khởi động các dịch vụ**

- Để khởi động dịch vụ, bạn chạy lệnh sau trong thư mục chứa file `docker-compose.yml`:

```bash
docker-compose up -d
```

### **7. Thêm dịch vụ và route vào Kong**

- Sử dụng Admin API của Kong để cấu hình dịch vụ và route. Gửi yêu cầu POST đến `http://localhost:8001/services` để thêm service `book_service`:

```bash
curl -i -X POST http://localhost:8001/services \
  --data "name=book_service" \
  --data "url=grpc://book-service:50051"
```

- Tiếp theo, thêm route cho service:

```bash
curl -i -X POST http://localhost:8001/services/book_service/routes \
  --data "paths[]=/books" \
  --data "protocols[]=http" \
  --data "protocols[]=grpc"
```

### **8. Gửi yêu cầu đến Kong**

Giờ đây, bạn có thể gửi yêu cầu HTTP đến Kong để truy cập vào service gRPC. Ví dụ, gửi yêu cầu HTTP tới đường dẫn `/books` với phương thức POST để lấy thông tin sách:

```bash
curl -i -X POST http://localhost:8000/books \
  --header "Content-Type: application/json" \
  --data '{"id": "1"}'
```

### **Kết quả**

- Kong sẽ chuyển đổi yêu cầu HTTP này thành yêu cầu gRPC và gửi đến `book-service`
- Phản hồi từ gRPC service sẽ được chuyển đổi lại thành HTTP response và trả về cho client

### **Kết luận**

- Sử dụng Kong như một gateway để điều phối các yêu cầu HTTP đến các gRPC services là một cách hiệu quả để tích hợp cả hai giao thức
- Bằng cách này, bạn có thể dễ dàng mở rộng và quản lý các service của mình mà không cần phải thay đổi cách client tương tác với chúng
