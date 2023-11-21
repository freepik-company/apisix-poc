.EXPORT_ALL_VARIABLES:

POD_NAME_API=$(shell kubectl get pods --selector=app=api --template '{{range .items}}{{.metadata.name}}{{end}}')
#PID=$(shell ps aux | grep -i 4504:80 | grep -v grep | awk '{print $$2}')

help: ## Help
	@for mkfile in $(sort $(MAKEFILE_LIST)); do \
		grep -E '^## .*$$' $$mkfile | awk 'BEGIN {FS = "## "}; {printf "\033[0;31m%-32s\033[0m\n", $$2}'; \
		grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $$mkfile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-32s\033[0m %s\n", $$1, $$2}'; \
	done

start: ## Start APISIX gateway
	@docker compose up -d
	@sleep 2
	@make configure

stop: ## Stop APISIX gateway
	@docker compose down -v
	@ps aux | grep -i 4504:80 | grep -v grep | awk '{print $$2}' | xargs kill

restart: ## Restart APISIX gateway
	@make stop
	@make start

status: ## Status of the containers
	@docker compose ps

configure: ## Create APISIX configuration
	@kubectl port-forward --address 0.0.0.0 $(POD_NAME_API) 4504:80 &
	@./apisix.sh create

test-free-resources-download: ## Test APISIX resources download endpoint (free user)
	./apisix.sh test free-resources-download

test-free-icons-download: ## Test APISIX icons download endpoint (free user)
	./apisix.sh test free-icons-download

test-free-download: ## Test APISIX legacy download endpoint (free user)
	./apisix.sh test free-download

test-premium-resources-download: ## Test APISIX resources download endpoint (premium user)
	./apisix.sh test test-premium-resources-download

test-premium-icons-download: ## Test APISIX icons download endpoint (premium user)
	./apisix.sh test test-premium-icons-download

test-premium-download: ## Test APISIX legacy download endpoint (premium user)
	./apisix.sh test test-premium-download

load: ## Make a load benchmarking
	./apisix.sh load