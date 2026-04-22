package db

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// createRandomAccount creates a user first (required by the fk_accounts_owner
// constraint) then inserts an account owned by that user. Both the user and
// account rows are asserted before the account is returned.
func createRandomAccount(t *testing.T) Account {
	t.Helper()
	user := createRandomUser(t)
	arg := CreateAccountParams{
		Owner:    user.Username,
		Balance:  randomMoney(),
		Currency: randomCurrency(),
	}

	account, err := testQueries.CreateAccount(context.Background(), arg)
	require.NoError(t, err)
	require.NotEmpty(t, account)
	require.Equal(t, arg.Owner, account.Owner)
	require.Equal(t, arg.Balance, account.Balance)
	require.Equal(t, arg.Currency, account.Currency)
	require.NotZero(t, account.ID)
	require.NotZero(t, account.CreatedAt)
	return account
}

func TestCreateAccount(t *testing.T) {
	t.Parallel()
	createRandomAccount(t)
}

func TestGetAccount(t *testing.T) {
	t.Parallel()
	created := createRandomAccount(t)

	fetched, err := testQueries.GetAccount(context.Background(), created.ID)
	require.NoError(t, err)
	require.NotEmpty(t, fetched)
	require.Equal(t, created.ID, fetched.ID)
	require.Equal(t, created.Owner, fetched.Owner)
	require.Equal(t, created.Balance, fetched.Balance)
	require.Equal(t, created.Currency, fetched.Currency)
	require.WithinDuration(t, created.CreatedAt, fetched.CreatedAt, time.Second)
}

func TestGetAccount_NotFound(t *testing.T) {
	t.Parallel()
	_, err := testQueries.GetAccount(context.Background(), -1)
	require.ErrorIs(t, err, sql.ErrNoRows)
}

func TestGetAccountForUpdate(t *testing.T) {
	t.Parallel()
	created := createRandomAccount(t)

	fetched, err := testQueries.GetAccountForUpdate(context.Background(), created.ID)
	require.NoError(t, err)
	require.Equal(t, created.ID, fetched.ID)
	require.Equal(t, created.Balance, fetched.Balance)
}

func TestUpdateAccount(t *testing.T) {
	t.Parallel()
	created := createRandomAccount(t)
	newBalance := randomMoney()

	updated, err := testQueries.UpdateAccount(context.Background(), UpdateAccountParams{
		ID:      created.ID,
		Balance: newBalance,
	})
	require.NoError(t, err)
	require.Equal(t, created.ID, updated.ID)
	require.Equal(t, newBalance, updated.Balance)
	require.Equal(t, created.Owner, updated.Owner)
	require.Equal(t, created.Currency, updated.Currency)
}

func TestAddAccountBalance(t *testing.T) {
	t.Parallel()
	created := createRandomAccount(t)
	delta := randomMoney()

	updated, err := testQueries.AddAccountBalance(context.Background(), AddAccountBalanceParams{
		ID:     created.ID,
		Amount: delta,
	})
	require.NoError(t, err)
	require.Equal(t, created.ID, updated.ID)
	require.Equal(t, created.Balance+delta, updated.Balance)
}

func TestDeleteAccount(t *testing.T) {
	t.Parallel()
	created := createRandomAccount(t)

	err := testQueries.DeleteAccount(context.Background(), created.ID)
	require.NoError(t, err)

	_, err = testQueries.GetAccount(context.Background(), created.ID)
	require.ErrorIs(t, err, sql.ErrNoRows)
}

func TestListAccounts(t *testing.T) {
	t.Parallel()
	// unique constraint: one account per (owner, currency) — max 3 per user
	user := createRandomUser(t)
	for _, currency := range currencies {
		_, err := testQueries.CreateAccount(context.Background(), CreateAccountParams{
			Owner:    user.Username,
			Balance:  randomMoney(),
			Currency: currency,
		})
		require.NoError(t, err)
	}

	accounts, err := testQueries.ListAccounts(context.Background(), ListAccountsParams{
		Owner:  user.Username,
		Limit:  2,
		Offset: 1,
	})
	require.NoError(t, err)
	require.Len(t, accounts, 2)
	for _, a := range accounts {
		require.Equal(t, user.Username, a.Owner)
		require.NotEmpty(t, a)
	}
}
