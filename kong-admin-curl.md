# Gửi request tới Kong để kiểm tra các services

## 1. Kiểm tra installed plugins

### Liệt kê tất cả các plugin đã được kích hoạt trên Kong bằng lệnh curl

- curl -i -X GET http://localhost:8001/plugins/enabled

### Kiểm tra phản hồi:

- Lệnh trên sẽ trả về danh sách tất cả các plugin đã được cài đặt và kích hoạt trên Kong. Nếu plugin grpc-web có trong danh sách, bạn sẽ thấy nó ở phần enabled_plugins

curl -i -X POST http://localhost:8001/routes/130f3cdb-923d-429f-8b64-367e80c4bf94/plugins \
 --data "name=grpc-web"
