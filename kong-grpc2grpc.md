# Create a gRPC service to Kong

## Single gRPC service

```bash
# create a gRPC service name=book and listen on localhost:8082
curl -XPOST localhost:8001/services \
   --data name=book \
   --data protocol=grpc \
   --data host=localhost \
   --data port=8082
```

### Single route

```bash
# create a gRPC route for book gRPC-service
curl -XPOST localhost:8001/services/book/routes \
   --data protocols=grpc \
   --data name=catch-all \
   --data paths=/
```

```bash
# using the grpcurl command line client to make a gRPC request
# install go and grpcurl on server
grpcurl -v -d '{"title": "Kong!", "author": "root", "publish_year": "2020"}' \
   -plaintext localhost:9080 book.BookService.ListBooks
```

### Multiple routes

```bash
# Create a route for GetBook
 curl -X POST localhost:8001/services/book/routes \
   --data protocols=grpc \
   --data paths=/book.BookService/GetBook \
   --data name=get-book

# Issue a gRPC request to the GetBook method
grpcurl -v -d '{"greeting": "Kong!"}' \
   -H 'kong-debug: 1' -plaintext \
   localhost:9080 book.BookService.GetBook
```

```bash
# Create a route for ListBooks
curl -X POST localhost:8001/services/book/routes \
   --data protocols=grpc \
   --data paths=/book.BookService/ListBooks \
   --data name=list-books

# issue a request to the ListBooks gRPC method
grpcurl -v -d '{"greeting": "Kong!"}' \
   -H 'kong-debug: 1' -plaintext \
   -H 'Content-Type: application/grpc' \
   localhost:9080 book.BookService.ListBooks
```

```bash
grpcurl \
 -H 'Content-Type: application/grpc' \
 -plaintext localhost:8000 book.BookService.ListBooks
```

```bash
curl -i http://localhost:8001/routes/{route_id}/plugins
curl -i http://localhost:8001/routes/e615c9d7-dfb3-46bb-8f26-e272d7d2dd1e/plugins
```

### Liệt kê tất cả các routes để tìm route_id:

```bash
curl -i -X GET http://localhost:8001/routes
```

### Lọc route cụ thể theo service:

```bash
curl -i -X GET http://localhost:8001/services/{service_name}/routes
curl -i -X GET http://localhost:8001/services/book_service/routes
```

### Cài Đặt Plugin Trên Route:

```bash
curl -i -X POST http://localhost:8001/routes/{route_id}/plugins \
 --data "name=grpc-web"
curl -i -X POST http://localhost:8001/routes/e615c9d7-dfb3-46bb-8f26-e272d7d2dd1e/plugins \
 --data "name=grpc-web"

# Kiểm tra plugin đã cài đặt
curl -i http://localhost:8001/routes/{route_id}/plugins
curl -i http://localhost:8001/routes/e615c9d7-dfb3-46bb-8f26-e272d7d2dd1e/plugins
```

### Cài Đặt Plugin Trên Service:

```bash
curl -i -X POST http://localhost:8001/services/{service_id}/plugins \
 --data "name=grpc-web"
curl -i -X POST http://localhost:8001/services/63a137f5-808b-44be-a3be-ba90c915da11/plugins \
 --data "name=grpc-web"

# Kiểm tra plugin đã cài đặt
curl -i http://localhost:8001/services/{service_id}/plugins
curl -i http://localhost:8001/services/63a137f5-808b-44be-a3be-ba90c915da11/plugins
```

```bash
grpcurl -v -d '{}' \
  -H 'kong-debug: 1' \
  -H 'Content-Type: application/grpc' \
  -plaintext \
  localhost:8000 book.BookServiceClient.ListBooks
```
