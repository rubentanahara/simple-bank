-- Drop tables in reverse dependency order
-- Tables that reference others must be dropped first

DROP TABLE IF EXISTS "sessions" CASCADE;
DROP TABLE IF EXISTS "transfers" CASCADE;
DROP TABLE IF EXISTS "entries" CASCADE;
DROP TABLE IF EXISTS "accounts" CASCADE;
DROP TABLE IF EXISTS "verify_emails" CASCADE;
DROP TABLE IF EXISTS "users" CASCADE;
