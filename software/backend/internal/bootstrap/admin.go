package bootstrap

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log/slog"
	"strings"

	"backend/internal/db"

	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/crypto/bcrypt"
)

// BootstrapResult contains the outcome of the initial System Admin check.
// TemporaryPassword is only populated when a new System Admin is created for the first time.
type BootstrapResult struct {
	Created           bool
	Email             string
	TemporaryPassword string
}

// EnsureSystemAdmin checks if at least one system_admin exists in the database.
// If none exists and bootstrapEmail is configured, it creates the initial system_admin
// with a randomly generated one-time temporary password (stored as a bcrypt hash)
// and must_change_password = true.
func EnsureSystemAdmin(ctx context.Context, q *db.Queries, name, bootstrapEmail string, logger *slog.Logger) (BootstrapResult, error) {
	email := strings.ToLower(strings.TrimSpace(bootstrapEmail))
	if email == "" {
		return BootstrapResult{}, nil
	}

	count, err := q.CountSystemAdmins(ctx)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("count system admins: %w", err)
	}
	if count > 0 {
		return BootstrapResult{Created: false, Email: email}, nil
	}

	tempPass, err := generateTemporaryPassword(16)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("generate temporary password: %w", err)
	}

	hashBytes, err := bcrypt.GenerateFromPassword([]byte(tempPass), bcrypt.DefaultCost)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("hash temporary password: %w", err)
	}

	adminName := strings.TrimSpace(name)
	if adminName == "" {
		adminName = "System Admin"
	}

	user, err := q.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          pgtype.UUID{Valid: false},
		Name:               adminName,
		Email:              email,
		PasswordHash:       string(hashBytes),
		Role:               "system_admin",
		IsActive:           true,
		IsDefaultManager:   false,
		MustChangePassword: true,
	})
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("create bootstrap system_admin: %w", err)
	}

	if logger != nil {
		logger.Info("initial system_admin created (save temporary password now; it will not be shown again)",
			slog.String("email", user.Email),
			slog.String("temporary_password", tempPass),
		)
	}

	return BootstrapResult{
		Created:           true,
		Email:             user.Email,
		TemporaryPassword: tempPass,
	}, nil
}

func generateTemporaryPassword(byteLen int) (string, error) {
	buf := make([]byte, byteLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
