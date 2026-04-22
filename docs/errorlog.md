# Error Log

Track of blockers, errors, and resolutions encountered during development.

---

## [2026-04-21] Docker PostgreSQL — role does not exist

**Context:** Trying to create `simple_bank` database inside `postgres12` Docker container via `/bin/sh`.

**Error:**
```
createdb: error: could not connect to database template1: FATAL: role "root" does not exist
```

**Commands that failed:**
```sh
createdb --username=root --owner=root simple_bank
createdb simple_bank
createdb --host=localhost --username=root --owner=postgres simple_bank
```

**Root cause:** The container was configured with a custom PostgreSQL user (`postgres-user`), not the typical `postgres` or OS `root` user. The user is set via the `POSTGRES_USER` environment variable in the Docker container config.

**Resolution:** Use the correct PostgreSQL user from the container's env:
```sh
# From host machine (recommended)
docker exec postgres12 createdb --username="postgres-user" --owner="postgres-user" simple_bank

# Or inside the container shell
createdb --username="postgres-user" --owner="postgres-user" simple_bank
```

**How to check the correct user in future:**
```sh
docker inspect postgres12 --format='{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES
```

---
