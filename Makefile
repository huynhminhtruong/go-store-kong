# global environments
# services
SERVICE = book-service
KONG_ADMIN_DASHBOARD = http://localhost:8001

# kong admin
# get list of created services
kong-admin-get-services:
	@curl -i -X GET ${KONG_ADMIN_DASHBOARD}/services

# get list of created routes of specific service
kong-admin-get-routes:
	@curl -i -X GET ${KONG_ADMIN_DASHBOARD}/services/${SERVICE}/routes
