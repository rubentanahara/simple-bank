# AGENTS.md

## Critical Setup

- **Docker must be running** before integration tests. On macOS with OrbStack: `orbctl start` then `docker start postgres12` if container exists.
- **PostgreSQL must be running** before `make cover` or integration tests. Run `make postgres-start` first.
- The PostgreSQL user is `postgres-user` (not `postgres` or `root`). Always use `-U postgres-user` when connecting manually.

## Common Commands

```bash
# Setup (run once after docker is ready)
make createdb   # create simple_bank database
make db-up     # apply migrations

# Testing
make test               # unit tests only (no DB required)
make test-integration   # integration tests (requires postgres-start + db-up)
make cover              # coverage (requires postgres-start)

# Code generation
make sqlc   # regenerate from db/query/*.sql (never edit internal/repository/sqlc/ directly)
```

## Key Conventions

- Edit SQL queries in `db/query/*.sql`, then run `make sqlc` to regenerate Go code.
- Migrations go in `db/migration/`, numbered sequentially (`000002_...`), always include `.down.sql`.
- Two test tiers: unit in `internal/usecase/` (mocks), integration in `internal/repository/sqlc/` (live DB).