package db_test

import (
	"context"
	"os"
	"testing"
	"time"

	"backend/internal/db"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

func testDBURL() string {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	return "postgres://termoscan:termoscan@localhost:5432/termoscan?sslmode=disable"
}

func TestSchemaTablesAndQueries(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	conn, err := pgx.Connect(ctx, testDBURL())
	if err != nil {
		t.Skipf("PostgreSQL not reachable for integration test: %v", err)
	}
	defer conn.Close(ctx)

	// 1. Verify all 17 tables exist in public schema
	var tableCount int
	err = conn.QueryRow(ctx, `
		SELECT count(*)
		FROM information_schema.tables
		WHERE table_schema = 'public'
		  AND table_type = 'BASE TABLE'
	`).Scan(&tableCount)
	if err != nil {
		t.Fatalf("failed to count tables: %v", err)
	}
	if tableCount != 17 {
		t.Fatalf("expected 17 tables in public schema, got %d", tableCount)
	}

	// 2. Run transactional tests using sqlc Queries and roll back at the end
	tx, err := conn.Begin(ctx)
	if err != nil {
		t.Fatalf("failed to begin tx: %v", err)
	}
	defer tx.Rollback(ctx)

	q := db.New(tx)

	// Create company
	company, err := q.CreateCompany(ctx, db.CreateCompanyParams{
		Name:    "SolarCorp Test",
		Address: pgtype.Text{String: "Av. Sete de Setembro, 3165", Valid: true},
	})
	if err != nil {
		t.Fatalf("CreateCompany failed: %v", err)
	}

	// Create default manager
	defaultMgr, err := q.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          company.ID,
		Name:               "Default Manager",
		Email:              "  MANAGER@SOLARCORP.COM  ",
		PasswordHash:       "$2a$10$dummyhashvalue1234567890123456789012345678901234",
		Role:               "manager",
		IsActive:           true,
		IsDefaultManager:   true,
		MustChangePassword: true,
	})
	if err != nil {
		t.Fatalf("CreateUser (default manager) failed: %v", err)
	}
	if defaultMgr.Email != "manager@solarcorp.com" {
		t.Fatalf("expected normalized email 'manager@solarcorp.com', got %q", defaultMgr.Email)
	}

	// Verify GetUserByEmail returns company_is_active = true
	fetchedMgr, err := q.GetUserByEmail(ctx, "MANAGER@solarcorp.com")
	if err != nil {
		t.Fatalf("GetUserByEmail failed: %v", err)
	}
	if !fetchedMgr.CompanyIsActive || fetchedMgr.ID != defaultMgr.ID {
		t.Fatalf("unexpected GetUserByEmail result: %+v", fetchedMgr)
	}

	// Verify trigger protect_default_manager prevents deactivating default manager
	_, err = tx.Exec(ctx, "SAVEPOINT before_protect_test")
	if err != nil {
		t.Fatalf("failed to create savepoint: %v", err)
	}
	_, err = tx.Exec(ctx, "UPDATE users SET is_active = false WHERE id = $1", defaultMgr.ID)
	if err == nil {
		t.Fatalf("expected error when deactivating default manager, got nil")
	}
	_, _ = tx.Exec(ctx, "ROLLBACK TO SAVEPOINT before_protect_test")

	// Create technician and link to manager
	tech, err := q.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          company.ID,
		Name:               "Tech One",
		Email:              "tech1@solarcorp.com",
		PasswordHash:       "$2a$10$dummyhashvalue1234567890123456789012345678901234",
		Role:               "technician",
		IsActive:           true,
		IsDefaultManager:   false,
		MustChangePassword: true,
	})
	if err != nil {
		t.Fatalf("CreateUser (technician) failed: %v", err)
	}

	_, err = q.AddTechnicianManager(ctx, db.AddTechnicianManagerParams{
		CompanyID:    company.ID,
		TechnicianID: tech.ID,
		ManagerID:    defaultMgr.ID,
	})
	if err != nil {
		t.Fatalf("AddTechnicianManager failed: %v", err)
	}

	mgrCount, err := q.CountManagersForTechnician(ctx, db.CountManagersForTechnicianParams{
		CompanyID:    company.ID,
		TechnicianID: tech.ID,
	})
	if err != nil || mgrCount != 1 {
		t.Fatalf("expected 1 manager for technician, got %d (err=%v)", mgrCount, err)
	}

	// Create and revoke auth session
	sess, err := q.CreateAuthSession(ctx, db.CreateAuthSessionParams{
		UserID:           defaultMgr.ID,
		RefreshTokenHash: "sha256_refresh_token_hash_test",
		ExpiresAt:        time.Now().Add(24 * time.Hour),
	})
	if err != nil {
		t.Fatalf("CreateAuthSession failed: %v", err)
	}

	activeSess, err := q.GetActiveAuthSessionByTokenHash(ctx, sess.RefreshTokenHash)
	if err != nil {
		t.Fatalf("GetActiveAuthSessionByTokenHash failed: %v", err)
	}
	if activeSess.UserID != defaultMgr.ID {
		t.Fatalf("expected session user_id %v, got %v", defaultMgr.ID, activeSess.UserID)
	}

	if err := q.RevokeAllUserAuthSessions(ctx, defaultMgr.ID); err != nil {
		t.Fatalf("RevokeAllUserAuthSessions failed: %v", err)
	}

	_, err = q.GetActiveAuthSessionByTokenHash(ctx, sess.RefreshTokenHash)
	if err == nil {
		t.Fatalf("expected error fetching revoked session, got nil")
	}
}
