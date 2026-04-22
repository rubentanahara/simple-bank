package db

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func createRandomEntry(t *testing.T, account Account) Entry {
	t.Helper()

	arg := CreateEntryParams{
		AccountID: account.ID,
		Amount:    randomMoney(),
	}

	entry, err := testQueries.CreateEntry(context.Background(), arg)

	require.NoError(t, err)
	require.NotEmpty(t, entry)
	require.Equal(t, arg.AccountID, entry.AccountID)
	require.Equal(t, arg.Amount, entry.Amount)
	require.NotZero(t, entry.ID)
	require.NotZero(t, entry.CreatedAt)

	return entry

}

func TestCreateEntry(t *testing.T) {
	t.Parallel()
	account := createRandomAccount(t)
	createRandomEntry(t, account)
}

func TestGetEntry(t *testing.T) {
	t.Parallel()
	account := createRandomAccount(t)
	created := createRandomEntry(t, account)

	fetched, err := testQueries.GetEntry(context.Background(), created.ID)

	require.NoError(t, err)
	require.NotEmpty(t, fetched)
	require.Equal(t, created.ID, fetched.ID)
	require.Equal(t, created.AccountID, fetched.AccountID)
	require.Equal(t, created.Amount, fetched.Amount)
	require.WithinDuration(t, created.CreatedAt, fetched.CreatedAt, time.Second)

}

func TestGetEntry_NotFound(t *testing.T) {
	t.Parallel()
	_, err := testQueries.GetEntry(context.Background(), -1)
	require.ErrorIs(t, err, sql.ErrNoRows)
}

func TestListEntries(t *testing.T) {
	t.Parallel()
	account := createRandomAccount(t)

	for range 3 {
		createRandomEntry(t, account)
	}

	entries, err := testQueries.ListEntries(context.Background(), ListEntriesParams{
		AccountID: account.ID,
		Limit:     5,
		Offset:    0,
	})

	require.NoError(t, err)
	require.Len(t, entries, 3)
	for _, a := range entries {
		require.Equal(t, account.ID, a.AccountID)
		require.NotEmpty(t, a)
	}

}
