package bootstrap_test

import (
	"context"
	"os"
	"testing"
	"time"

	"backend/internal/bootstrap"
	"backend/internal/db"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

func testDBURL() string {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	return "postgres://termoscan:termoscan@localhost:5432/termoscan?sslmode=disable"
}

func TestEnsureSystemAdmin(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	conn, err := pgx.Connect(ctx, testDBURL())
	if err != nil {
		t.Skipf("PostgreSQL not reachable for integration test: %v", err)
	}
	defer conn.Close(ctx)

	tx, err := conn.Begin(ctx)
	if err != nil {
		t.Fatalf("failed to begin tx: %v", err)
	}
	defer tx.Rollback(ctx)

	q := db.New(tx)

	// Ensure clean state inside transaction
	_, err = tx.Exec(ctx, "DELETE FROM users WHERE role = 'system_admin'")
	if err != nil {
		t.Fatalf("failed to clear system_admin users in tx: %v", err)
	}

	// 1. First call should create the system_admin and return a one-time temporary password
	res1, err := bootstrap.EnsureSystemAdmin(ctx, q, "System Admin", "ADMIN@TERMOSCAN.LOCAL", nil)
	if err != nil {
		t.Fatalf("first EnsureSystemAdmin failed: %v", err)
	}
	if !res1.Created {
		t.Fatalf("expected Created=true on first bootstrap")
	}
	if res1.Email != "admin@termoscan.local" {
		t.Fatalf("expected normalized email 'admin@termoscan.local', got %q", res1.Email)
	}
	if len(res1.TemporaryPassword) < 16 {
		t.Fatalf("expected non-empty random temporary password, got %q", res1.TemporaryPassword)
	}

	// Verify stored user in DB has bcrypt hash and must_change_password = true
	u, err := q.GetUserByEmail(ctx, "admin@termoscan.local")
	if err != nil {
		t.Fatalf("GetUserByEmail failed: %v", err)
	}
	if u.Role != "system_admin" || !u.MustChangePassword || !u.IsActive || u.CompanyID.Valid {
		t.Fatalf("unexpected system_admin user state: %+v", u)
	}
	if err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(res1.TemporaryPassword)); err != nil {
		t.Fatalf("stored bcrypt hash does not match returned temporary password: %v", err)
	}

	// 2. Second call should be a no-op (Created=false, TemporaryPassword="")
	res2, err := bootstrap.EnsureSystemAdmin(ctx, q, "System Admin", "admin@termoscan.local", nil)
	if err != nil {
		t.Fatalf("second EnsureSystemAdmin failed: %v", err)
	}
	if res2.Created || res2.TemporaryPassword != "" {
		t.Fatalf("expected Created=false and empty TemporaryPassword on second call, got %+v", res2)
	}
}
