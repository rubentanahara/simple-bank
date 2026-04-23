# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- `Store` for executing DB transactions atomically with `TransferTx`
- `TransferTx` integration test covering transaction rollback on failure
- `AGENTS.md` with critical setup and common commands

## v0.1.0 - 2026-04-22

### Added
- Initial database schema with users, accounts, entries, transfers, sessions, verify_emails tables
- sqlc-generated Go code from SQL queries
- Integration tests for accounts and entries