.DEFAULT_GOAL := help

## —— Database ————————————————————————————————————————————————————————————————
postgres-start: ## Pull postgres:12-alpine and start container
	docker run --name postgres12 \
		-e POSTGRES_USER=postgres-user \
		-e POSTGRES_PASSWORD=postgres-password \
		-p 5432:5432 \
		-d postgres:12-alpine

createdb: ## Create simple_bank database inside the container
	docker exec -it postgres12 createdb --username=postgres-user --owner=postgres-user simple_bank

dropdb: ## Drop simple_bank database
	docker exec -it postgres12 dropdb --username=postgres-user simple_bank

postgres: ## Open a psql shell inside the container
	docker exec -it postgres12 psql -U postgres-user

## —— Migrations ——————————————————————————————————————————————————————————————
db-up: ## Apply all up migrations
	migrate -path db/migration -database "postgresql://postgres-user:postgres-password@localhost:5432/simple_bank?sslmode=disable" -verbose up

db-down: ## Roll back all migrations
	migrate -path db/migration -database "postgresql://postgres-user:postgres-password@localhost:5432/simple_bank?sslmode=disable" -verbose down

## —— Code generation —————————————————————————————————————————————————————————
sqlc: ## Regenerate Go code from SQL queries (never edit internal/repository/sqlc/ directly)
	sqlc generate

## —— Testing —————————————————————————————————————————————————————————————————
test: ## Run all unit tests (no live DB required)
	go test ./... -count=1

test-integration: ## Run sqlc integration tests (requires postgres-start + db-up)
	go test ./internal/repository/sqlc/... -v -count=1

test-race: ## Run all tests with the data-race detector
	go test -race ./... -count=1

## —— Coverage ————————————————————————————————————————————————————————————————
cover: ## Show per-function coverage in the terminal
	go test -coverprofile=coverage.out ./... -count=1
	go tool cover -func=coverage.out

cover-html: ## Open an interactive HTML coverage report in the browser
	go test -coverprofile=coverage.out ./... -count=1
	go tool cover -html=coverage.out

## —— Help ————————————————————————————————————————————————————————————————————
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_\/%·-]+:.*?##/ { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } \
		/^##/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

.PHONY: postgres-start createdb dropdb postgres db-up db-down sqlc \
        test test-integration test-race cover cover-html help
