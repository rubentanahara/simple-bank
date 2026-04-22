# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Database
make postgres-start   # pull postgres:12-alpine and start container (postgres-user / postgres-password)
make createdb         # create simple_bank database
make dropdb           # drop simple_bank database
make postgres         # open psql shell

# Migrations (golang-migrate)
make db-up            # apply all up migrations
make db-down          # roll back all migrations

# Code generation
make sqlc             # regenerate Go code from SQL queries

# Testing
make test                                       # all unit tests (no live DB required)
make test-integration                           # sqlc integration tests (requires postgres-start + db-up)
make test-race                                  # all tests with data-race detector
make test/pkg/usecase RUN=TestCreateAccount     # single test by name in a specific package
make cover                                      # coverage % per function (terminal)
make cover-html                                 # coverage report in browser
```

> The PostgreSQL user in the container is `postgres-user` (not `postgres` or `root`). Always pass `-U postgres-user` when connecting manually.

## Architecture

This project follows **clean architecture** with strict layer separation:

```
cmd/api/                    # Entry point (main.go — not yet created)
internal/
  domain/                   # Core entities and repository interfaces
  usecase/                  # Business rules, orchestrates domain
  repository/
    sqlc/                   # Generated DB access code (DO NOT EDIT — run make sqlc)
  delivery/
    http/                   # HTTP handlers
db/
  migration/                # SQL migrations (golang-migrate, numbered 000001_…)
  query/                    # SQL query sources consumed by sqlc
```

**Dependency rule:** outer layers depend on inner layers only. `delivery` → `usecase` → `domain`. `repository` implements `domain` interfaces.

## Database Layer

- **ORM:** none — [sqlc](https://sqlc.dev) generates fully type-safe Go from raw SQL.
- **Schema source of truth:** `db/migration/000001_init_schema.up.sql`
- **Query source of truth:** `db/query/*.sql` — edit these, then run `make sqlc` to regenerate `internal/repository/sqlc/`.
- **Never edit** files inside `internal/repository/sqlc/` directly.
- `sqlc.yaml` config: engine `postgresql`, schema from `db/migration/`, output to `internal/repository/sqlc/`, package name `db`.

## Data Model

- `users` — primary key `username` (varchar); roles: `depositor` (default) or `banker`
- `accounts` — one per `(owner, currency)` pair; balance stored as `bigint` (smallest currency unit); non-negative enforced by CHECK
- `entries` — ledger rows per account; amount can be negative (debit) or positive (credit)
- `transfers` — always positive amount; enforces `from_account_id != to_account_id`
- `sessions` — refresh token store, blockable; `client_ip` stored as PostgreSQL `INET`
- `verify_emails` — email verification codes with 15-minute expiry

All foreign keys are `DEFERRABLE INITIALLY IMMEDIATE`. Cascades: sessions/verify_emails cascade-delete with user; entries cascade-delete with account; accounts/transfers restrict delete.

## Module

`github.com/rubentanahara/simple_bank` — Go 1.26.

| Dependency | Purpose |
|-----------|---------|
| `github.com/google/uuid` | UUID generation (sessions) |
| `github.com/sqlc-dev/pqtype` | PostgreSQL `INET` type for `sessions.client_ip` |
| `github.com/lib/pq` | PostgreSQL driver for `database/sql` |
| `github.com/stretchr/testify` | Test assertions (`require.*`) |

## Go Code Style & Conventions

- Use `errors.New` / `fmt.Errorf("%w", err)` — never swallow errors silently.
- Return `(T, error)` from all fallible functions; no `panic` outside `main` init.
- First parameter of every I/O-touching function must be `context.Context`.
- Name single-method interfaces with the `-er` suffix (e.g. `AccountCreator`).
- Keep unexported until a second caller demands it.
- Split any function that requires a section comment into smaller functions.

### Doc comments

| What | Comment? | Rule |
|------|----------|------|
| Exported interface / type | Always | Start with the identifier name; document error cases and invariants |
| Exported `New*` constructor | Always | Note any required non-nil params or preconditions |
| Exported method | Always | Describe what it does beyond the name; list meaningful error returns |
| Unexported function | Only when WHY is non-obvious | Concurrency tricks, constraint workarounds, non-obvious side effects |
| `Test*` functions | Never | Name encodes intent (`TestGetAccount_NotFound`) |
| sqlc-generated files | Never | Overwritten by `make sqlc` |

Format: one line starting with the identifier name, then detail on subsequent lines if needed.

```go
// AccountRepository defines persistence operations for bank accounts.
// All implementations must be safe for concurrent use.
type AccountRepository interface {
    // CreateAccount inserts a new account. Returns ErrDuplicateCurrency if
    // the owner already holds an account in the given currency.
    CreateAccount(ctx context.Context, arg CreateAccountParams) (Account, error)
}
```

**Never** restate what the name already says (`// GetAccount gets the account`). If removing the comment would not confuse a future reader, don't write it.

## SOLID in This Codebase

- **SRP** — one struct, one responsibility. Usecases orchestrate; they never format HTTP responses or build SQL.
- **OCP** — extend via new usecase/repository implementations; never patch generated sqlc files.
- **LSP** — repository structs must fully satisfy their `domain` interface; no stub methods that panic.
- **ISP** — define narrow interfaces in `domain`; do not expose the full `Querier` to a usecase that needs one method.
- **DIP** — `usecase` depends on `domain` interfaces only, never on `repository/sqlc` concrete types.

## Unit Testing

**Two test tiers exist:**

| Tier | Location | Needs live DB? |
|------|----------|---------------|
| Integration | `internal/repository/sqlc/*_test.go` | Yes — run `make postgres-start && make db-up` first |
| Unit | `internal/usecase/`, `internal/delivery/http/` | No — mocks only |

Integration tests in `sqlc/` use `main_test.go` to open a real connection; `util_test.go` provides `createRandomUser` / `createRandomAccount` helpers shared across all sqlc test files.

### Add mock support (not yet installed)

```bash
go get go.uber.org/mock/mockgen@latest
go get go.uber.org/mock/gomock@latest
```

### Generate mocks from domain interfaces

```bash
# Run from repo root; repeat for each interface in internal/domain/
mockgen -source=internal/domain/account_repository.go \
        -destination=internal/domain/mock/mock_account_repository.go \
        -package=mockdomain
```

### Test file layout

```
internal/
  usecase/
    account_usecase_test.go   # unit tests — mock the domain repo interface
  delivery/http/
    account_handler_test.go   # unit tests — mock the usecase interface
```

### Usecase unit test pattern

```go
func TestCreateAccount_Success(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockRepo := mockdomain.NewMockAccountRepository(ctrl)
    uc := usecase.NewAccountUsecase(mockRepo)

    mockRepo.EXPECT().
        CreateAccount(gomock.Any(), gomock.Any()).
        Return(domain.Account{ID: 1, Owner: "alice"}, nil)

    got, err := uc.CreateAccount(context.Background(), domain.CreateAccountParams{
        Owner:    "alice",
        Currency: "USD",
    })

    require.NoError(t, err)
    require.Equal(t, int64(1), got.ID)
}
```

### HTTP handler unit test pattern

```go
func TestCreateAccountHandler_Success(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockUC := mockusecase.NewMockAccountUsecase(ctrl)
    h := handler.NewAccountHandler(mockUC)

    mockUC.EXPECT().CreateAccount(gomock.Any(), gomock.Any()).
        Return(domain.Account{ID: 1}, nil)

    body := `{"owner":"alice","currency":"USD"}`
    req := httptest.NewRequest(http.MethodPost, "/accounts", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()

    h.CreateAccount(rec, req)

    require.Equal(t, http.StatusCreated, rec.Code)
}
```

### Rules

- **Never mock `db.Querier` directly in usecase tests** — mock the `domain` interface instead.
- **Never hit a real database in unit tests** — that is an integration test; keep them separate.
- Name tests `TestFunctionName_Scenario` (e.g. `TestCreateAccount_InsufficientFunds`).
- Use table-driven tests with `t.Run` for multiple input/output cases.
- Call `t.Parallel()` at the top of every test and subtest that has no shared mutable state.
- One `*testing.T` per test function — never share controllers across tests.

## Don'ts

- **Never edit** `internal/repository/sqlc/` — regenerate via `make sqlc`.
- **Never import** `delivery` or `repository` packages from `domain` or `usecase`.
- **Never store** plaintext secrets or passwords in source files or logs.
- **Never use** `interface{}` / `any` where a concrete type can be used.
- **Never commit** a migration without a matching `.down.sql` rollback.
- **Never bypass** the `CHECK (balance >= 0)` DB constraint by updating balances outside the DB layer.
- **Never add** business logic inside HTTP handlers — handlers call usecases only.
- **Never use** `init()` functions; initialize explicitly in `main`.
- **Never mock** `db.Querier` in usecase tests — mock the domain interface.

## Permissions

| Action | Allowed |
|--------|---------|
| Edit `internal/repository/sqlc/` files | No — run `make sqlc` |
| Edit `db/query/*.sql` then regenerate | Yes |
| Add new migrations | Yes — number sequentially (`000002_…`), include `.down.sql` |
| Add dependencies to `go.mod` | Yes — `go get <pkg>@<version>` only |
| Add a new `domain` interface | Yes |
| Add a new HTTP handler | Yes — wire via usecase in `cmd/api/main.go` |
| Drop or alter existing tables | Only via a new migration, never ad-hoc SQL |
| Push to `main` without passing `go test ./...` | No |
