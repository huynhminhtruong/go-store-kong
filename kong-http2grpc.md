# Dưới đây là hướng dẫn chi tiết để cấu hình Kong Gateway nhận RESTful API và chuyển tiếp chúng đến các gRPC services:

### Bước 1: Cấu hình Kong Service trỏ đến gRPC Service

1. **Tạo một service trong Kong**: Service này sẽ là điểm cuối mà Kong Gateway sẽ chuyển tiếp đến gRPC service của bạn

   Ví dụ, tạo một service trong Kong trỏ đến gRPC service chạy ở `localhost:50051`:

   ```bash
   curl -i -X POST http://localhost:8001/services \
     --data name=grpc_service \
     --data url=grpc://localhost:50051
   ```

   - `grpc://localhost:50051` là địa chỉ gRPC service của service đang muốn trỏ tới(**localhost:8082** => trỏ tới grpc-book-service)
   - `name=grpc_service` là tên bạn đặt cho service trong Kong(**grpc_service=book_service**)

2. **Tạo route cho service**: Route này sẽ định nghĩa cách Kong tiếp nhận các yêu cầu RESTful API và chuyển tiếp chúng đến service đã tạo ở trên

   Ví dụ, tạo route trỏ đến service `grpc_service`(**name=book_service**):

   ```bash
   curl -i -X POST http://localhost:8001/services/grpc_service/routes \
     --data paths[]=/rest-to-grpc \
     --data methods[]=GET
   ```

   - `paths[]=/rest-to-grpc` xác định đường dẫn của API RESTful(**rest-to-grpc=/v1/books** => BookService.ListBooks service được define trong book.proto)
   - `methods[]=GET` xác định phương thức HTTP cho route này (có thể thay đổi nếu cần)

### Bước 2: Cài đặt plugin `grpc-web`

Plugin này sẽ giúp chuyển đổi từ HTTP/REST sang gRPC request để tương thích với gRPC service của bạn

1. Liệt kê tất cả các plugin đã được kích hoạt trên Kong bằng lệnh curl:

   ```bash
   curl -i http://localhost:8001/plugins
   curl -i -X GET http://localhost:8001/plugins/enabled
   ```

2. **Kiểm tra các installed plugins trên route**:

   ```bash

   ```

3. **Cài đặt grpc-web plugin trên route**:

   ```bash
   curl -i -X POST http://localhost:8001/routes/<route_id>/plugins \
     --data name=grpc-web
   ```

   Thay `<route_id>` bằng ID của route bạn vừa tạo. Bạn có thể lấy ID của route này bằng lệnh:

   ```bash
   curl -X GET http://localhost:8001/routes
   ```

### Bước 3: Cài đặt plugin `grpc-gateway`

Để Kong có thể chuyển tiếp yêu cầu REST đến đúng gRPC method trong `BookService`, bạn cần chỉ định thêm thông tin về method mà bạn muốn gọi. Điều này có thể được thực hiện bằng cách sử dụng plugin **grpc-gateway**, giúp ánh xạ các endpoint REST tới các method cụ thể trong gRPC service của bạn

Dưới đây là cách cấu hình cụ thể để ánh xạ yêu cầu REST đến các method trong `BookService`:

1. **Thêm Plugin grpc-gateway vào Route**: Plugin này sẽ giúp Kong xác định các yêu cầu HTTP đến các method cụ thể trong gRPC service

   Ví dụ, để cấu hình cho method `ListBooks`:

   ```bash
   curl -i -X POST http://localhost:8001/routes/<route_id>/plugins \
     --data name=grpc-gateway \
     --data config.proto_path=/path/to/book.proto \
     --data config.package=book_package \
     --data config.service=BookService \
     --data config.method=ListBooks
   ```

   - `config.proto_path`: Đường dẫn đến file `book.proto` chứa các định nghĩa của service
   - `config.package`: Tên package trong `book.proto` (nếu có). Nếu không có package, có thể để trống
   - `config.service`: Tên service mà bạn muốn gọi, ở đây là `BookService`
   - `config.method`: Tên method cụ thể, ví dụ `ListBooks`

   Lưu ý: Thay `<route_id>` bằng ID của route trỏ đến `grpc_service`

2. **Tạo route cho từng method của gRPC Service**: Nếu bạn có nhiều method, bạn cần tạo các route riêng biệt cho từng method, mỗi route lại cấu hình grpc-gateway plugin cho đúng method đó. Ví dụ:

   - **Tạo route cho `Create` method**:

     ```bash
     curl -i -X POST http://localhost:8001/services/grpc_service/routes \
       --data paths[]=/create-book \
       --data methods[]=POST

     curl -i -X POST http://localhost:8001/routes/<route_id_create>/plugins \
       --data name=grpc-gateway \
       --data config.proto_path=/path/to/book.proto \
       --data config.package=book_package \
       --data config.service=BookService \
       --data config.method=Create
     ```

   - **Tạo route cho `GetBook` method**:

     ```bash
     curl -i -X POST http://localhost:8001/services/grpc_service/routes \
       --data paths[]=/get-book \
       --data methods[]=GET

     curl -i -X POST http://localhost:8001/routes/<route_id_getbook>/plugins \
       --data name=grpc-gateway \
       --data config.proto_path=/path/to/book.proto \
       --data config.package=book_package \
       --data config.service=BookService \
       --data config.method=GetBook
     ```

   Mỗi route tương ứng với một endpoint REST (ví dụ: `/create-book`, `/get-book`, v.v.), ánh xạ đến một method gRPC tương ứng

### Kiểm tra

Bạn có thể gửi yêu cầu đến các endpoint REST vừa tạo để kiểm tra:

- **Tạo sách mới**:

  ```bash
  curl -X POST http://localhost:8000/create-book \
    -H "Content-Type: application/json" \
    -d '{ "title": "My New Book", "author": "Author Name" }'
  ```

- **Lấy thông tin sách**:

  ```bash
  curl -X GET http://localhost:8000/get-book \
    -H "Content-Type: application/json" \
    -d '{ "book_id": "123" }'
  ```

Cấu hình này sẽ cho phép Kong định tuyến chính xác đến từng method trong `BookService`

### Bước 4: Kiểm tra cấu hình

Gửi thử một yêu cầu HTTP POST đến endpoint `/rest-to-grpc` mà bạn đã cấu hình:

```bash
curl -X POST http://localhost:8000/rest-to-grpc \
  -H "Content-Type: application/json" \
  -d '{ "key": "value" }'
```

### Tổng quan các thành phần chính

- **Kong Service**: Trỏ đến địa chỉ của gRPC service
- **Kong Route**: Định nghĩa endpoint RESTful và liên kết với service
- **grpc-web Plugin**: Chuyển đổi yêu cầu HTTP thành gRPC để tương thích với backend
