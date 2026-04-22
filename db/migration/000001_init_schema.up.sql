-- Users table - base table for authentication and profile
CREATE TABLE IF NOT EXISTS "users" (
  "username" VARCHAR(255) NOT NULL PRIMARY KEY,
  "role" VARCHAR(50) NOT NULL DEFAULT 'depositor',
  "hashed_password" VARCHAR(255) NOT NULL,
  "full_name" VARCHAR(255) NOT NULL,
  "email" VARCHAR(255) UNIQUE NOT NULL,
  "is_email_verified" BOOLEAN NOT NULL DEFAULT false,
  "password_changed_at" TIMESTAMPTZ NOT NULL DEFAULT '0001-01-01 00:00:00Z',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "ck_users_role" CHECK ("role" IN ('depositor', 'banker')),
  CONSTRAINT "ck_users_username_length" CHECK (LENGTH(TRIM("username")) > 0),
  CONSTRAINT "ck_users_email_length" CHECK (LENGTH(TRIM("email")) > 0)
);

-- Email verification table
CREATE TABLE IF NOT EXISTS "verify_emails" (
  "id" BIGSERIAL NOT NULL PRIMARY KEY,
  "username" VARCHAR(255) NOT NULL,
  "email" VARCHAR(255) NOT NULL,
  "secret_code" VARCHAR(255) NOT NULL UNIQUE,
  "is_used" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expired_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP + INTERVAL '15 minutes',

  CONSTRAINT "fk_verify_emails_username" FOREIGN KEY ("username")
    REFERENCES "users" ("username")
    ON DELETE CASCADE
    DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT "ck_verify_emails_expiry" CHECK ("expired_at" > "created_at")
);

-- Bank accounts table
CREATE TABLE IF NOT EXISTS "accounts" (
  "id" BIGSERIAL NOT NULL PRIMARY KEY,
  "owner" VARCHAR(255) NOT NULL,
  "balance" BIGINT NOT NULL DEFAULT 0,
  "currency" VARCHAR(3) NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "fk_accounts_owner" FOREIGN KEY ("owner")
    REFERENCES "users" ("username")
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT "ck_accounts_balance_nonneg" CHECK ("balance" >= 0),
  CONSTRAINT "ck_accounts_currency_length" CHECK (LENGTH(TRIM("currency")) = 3),
  CONSTRAINT "uq_accounts_owner_currency" UNIQUE ("owner", "currency")
);

-- Transaction entries table
CREATE TABLE IF NOT EXISTS "entries" (
  "id" BIGSERIAL NOT NULL PRIMARY KEY,
  "account_id" BIGINT NOT NULL,
  "amount" BIGINT NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "fk_entries_account_id" FOREIGN KEY ("account_id")
    REFERENCES "accounts" ("id")
    ON DELETE CASCADE
    DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT "ck_entries_amount_nonzero" CHECK ("amount" != 0)
);

-- Transfers table
CREATE TABLE IF NOT EXISTS "transfers" (
  "id" BIGSERIAL NOT NULL PRIMARY KEY,
  "from_account_id" BIGINT NOT NULL,
  "to_account_id" BIGINT NOT NULL,
  "amount" BIGINT NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "fk_transfers_from_account_id" FOREIGN KEY ("from_account_id")
    REFERENCES "accounts" ("id")
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT "fk_transfers_to_account_id" FOREIGN KEY ("to_account_id")
    REFERENCES "accounts" ("id")
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT "ck_transfers_amount_positive" CHECK ("amount" > 0),
  CONSTRAINT "ck_transfers_different_accounts" CHECK ("from_account_id" != "to_account_id")
);

-- User sessions table
CREATE TABLE IF NOT EXISTS "sessions" (
  "id" UUID NOT NULL PRIMARY KEY,
  "username" VARCHAR(255) NOT NULL,
  "refresh_token" VARCHAR(255) NOT NULL UNIQUE,
  "user_agent" VARCHAR(512) NOT NULL,
  "client_ip" INET NOT NULL,
  "is_blocked" BOOLEAN NOT NULL DEFAULT false,
  "expires_at" TIMESTAMPTZ NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "fk_sessions_username" FOREIGN KEY ("username")
    REFERENCES "users" ("username")
    ON DELETE CASCADE
    DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT "ck_sessions_expiry" CHECK ("expires_at" > "created_at")
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS "idx_accounts_owner" ON "accounts" ("owner");
CREATE INDEX IF NOT EXISTS "idx_entries_account_id" ON "entries" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_entries_created_at" ON "entries" ("created_at");
CREATE INDEX IF NOT EXISTS "idx_transfers_from_account_id" ON "transfers" ("from_account_id");
CREATE INDEX IF NOT EXISTS "idx_transfers_to_account_id" ON "transfers" ("to_account_id");
CREATE INDEX IF NOT EXISTS "idx_transfers_created_at" ON "transfers" ("created_at");
CREATE INDEX IF NOT EXISTS "idx_verify_emails_username" ON "verify_emails" ("username");
CREATE INDEX IF NOT EXISTS "idx_verify_emails_secret_code" ON "verify_emails" ("secret_code");
CREATE INDEX IF NOT EXISTS "idx_sessions_username" ON "sessions" ("username");

-- Column comments for documentation
COMMENT ON COLUMN "entries"."amount" IS 'can be negative or positive; represents debit (negative) or credit (positive)';
COMMENT ON COLUMN "transfers"."amount" IS 'must be positive; represents amount being transferred from one account to another';
COMMENT ON COLUMN "users"."role" IS 'user role: depositor (default) or banker';
COMMENT ON COLUMN "sessions"."is_blocked" IS 'true if session is explicitly blocked/revoked by user or admin';
