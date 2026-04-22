package db

import (
	"context"
	"fmt"
	"math/rand"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

const alphabet = "abcdefghijklmnopqrstuvwxyz"

var currencies = []string{"USD", "EUR", "CAD"}

func randomString(n int) string {
	var sb strings.Builder
	for range n {
		sb.WriteByte(alphabet[rand.Intn(len(alphabet))])
	}
	return sb.String()
}

func randomOwner() string    { return randomString(8) }
func randomMoney() int64     { return rand.Int63n(1_000_000) }
func randomEmail() string    { return fmt.Sprintf("%s@example.com", randomString(10)) }
func randomCurrency() string { return currencies[rand.Intn(len(currencies))] }

// createRandomUser inserts a user with random credentials and asserts that
// the row round-trips correctly. Callers receive a fully validated User —
// any DB or constraint error fails the calling test immediately.
func createRandomUser(t *testing.T) User {
	t.Helper()
	arg := CreateUserParams{
		Username:       randomOwner(),
		HashedPassword: "hashed_" + randomString(12),
		FullName:       randomString(6) + " " + randomString(8),
		Email:          randomEmail(),
	}
	user, err := testQueries.CreateUser(context.Background(), arg)
	require.NoError(t, err)
	require.NotEmpty(t, user)
	require.Equal(t, arg.Username, user.Username)
	require.Equal(t, arg.Email, user.Email)
	return user
}
