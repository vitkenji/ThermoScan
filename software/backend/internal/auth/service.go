package auth

import (
	"context"
	"errors"
	"net/mail"
	"strings"
	"time"

	"backend/internal/db"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

var (
	ErrInvalidCredentials     = errors.New("invalid email or password")
	ErrInvalidRefreshToken    = errors.New("invalid or expired refresh token")
	ErrAccountInactive        = errors.New("user or company account is inactive")
	ErrInvalidCurrentPassword = errors.New("current password is incorrect")
	ErrWeakPassword           = errors.New("new password must be between 8 and 72 bytes")
	ErrSamePassword           = errors.New("new password must be different from current password")
	ErrInvalidInput           = errors.New("invalid input")
	ErrEmailAlreadyInUse      = errors.New("email is already in use")
)

type DB interface {
	db.DBTX
	Begin(ctx context.Context) (pgx.Tx, error)
}

type ResponsibleManagerDTO struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type UserDTO struct {
	ID                  string                  `json:"id"`
	CompanyID           *string                 `json:"company_id"`
	Name                string                  `json:"name"`
	Email               string                  `json:"email"`
	Role                string                  `json:"role"`
	IsActive            bool                    `json:"is_active"`
	IsDefaultManager    bool                    `json:"is_default_manager"`
	MustChangePassword  bool                    `json:"must_change_password"`
	ResponsibleManagers []ResponsibleManagerDTO `json:"responsible_managers,omitempty"`
	CreatedAt           string                  `json:"created_at"`
	UpdatedAt           string                  `json:"updated_at"`
}

type AuthResponse struct {
	AccessToken           string  `json:"access_token"`
	AccessTokenExpiresAt  string  `json:"access_token_expires_at"`
	RefreshToken          string  `json:"refresh_token"`
	RefreshTokenExpiresAt string  `json:"refresh_token_expires_at"`
	User                  UserDTO `json:"user"`
}

type Service struct {
	database DB
	queries  *db.Queries
	tokens   *TokenManager
}

func NewService(database DB, tokens *TokenManager) *Service {
	return &Service{
		database: database,
		queries:  db.New(database),
		tokens:   tokens,
	}
}

func (s *Service) Login(ctx context.Context, email, password string) (AuthResponse, error) {
	normalizedEmail := strings.ToLower(strings.TrimSpace(email))
	if normalizedEmail == "" || password == "" {
		return AuthResponse{}, ErrInvalidCredentials
	}

	u, err := s.queries.GetUserByEmail(ctx, normalizedEmail)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			DummyComparePassword(password)
			return AuthResponse{}, ErrInvalidCredentials
		}
		return AuthResponse{}, err
	}

	if err := ComparePassword(u.PasswordHash, password); err != nil {
		return AuthResponse{}, ErrInvalidCredentials
	}

	if !u.IsActive || !u.CompanyIsActive {
		return AuthResponse{}, ErrAccountInactive
	}

	now := time.Now().UTC()
	rawRefresh, refreshHash, err := GenerateRefreshToken()
	if err != nil {
		return AuthResponse{}, err
	}
	refreshExp := now.Add(RefreshTokenTTL)

	sess, err := s.queries.CreateAuthSession(ctx, db.CreateAuthSessionParams{
		UserID:           u.ID,
		RefreshTokenHash: refreshHash,
		ExpiresAt:        refreshExp,
	})
	if err != nil {
		return AuthResponse{}, err
	}

	accessToken, accessExp, err := s.tokens.GenerateAccessToken(sess.ID, u.ID, u.CompanyID, u.Role, u.MustChangePassword, now)
	if err != nil {
		return AuthResponse{}, err
	}

	userDTO := mapUserRowToDTO(u.ID, u.CompanyID, u.Name, u.Email, u.Role, u.IsActive, u.IsDefaultManager, u.MustChangePassword, u.CreatedAt, u.UpdatedAt)
	userDTO = s.EnrichUserDTO(ctx, userDTO, u.CompanyID, u.ID)

	return AuthResponse{
		AccessToken:           accessToken,
		AccessTokenExpiresAt:  accessExp.Format(time.RFC3339),
		RefreshToken:          rawRefresh,
		RefreshTokenExpiresAt: refreshExp.Format(time.RFC3339),
		User:                  userDTO,
	}, nil
}

func (s *Service) Refresh(ctx context.Context, rawRefreshToken string) (AuthResponse, error) {
	trimmed := strings.TrimSpace(rawRefreshToken)
	if trimmed == "" {
		return AuthResponse{}, ErrInvalidRefreshToken
	}

	tokenHash := HashRefreshToken(trimmed)

	tx, err := s.database.Begin(ctx)
	if err != nil {
		return AuthResponse{}, err
	}
	defer tx.Rollback(ctx)

	qtx := db.New(tx)

	sess, err := qtx.GetActiveAuthSessionByTokenHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AuthResponse{}, ErrInvalidRefreshToken
		}
		return AuthResponse{}, err
	}

	if !sess.UserIsActive || !sess.CompanyIsActive {
		_ = qtx.RevokeAllUserAuthSessions(ctx, sess.UserID)
		_ = tx.Commit(ctx)
		return AuthResponse{}, ErrAccountInactive
	}

	if err := qtx.RevokeAuthSessionByID(ctx, sess.ID); err != nil {
		return AuthResponse{}, err
	}

	u, err := qtx.GetUserByID(ctx, sess.UserID)
	if err != nil {
		return AuthResponse{}, err
	}

	now := time.Now().UTC()
	newRawRefresh, newRefreshHash, err := GenerateRefreshToken()
	if err != nil {
		return AuthResponse{}, err
	}
	refreshExp := now.Add(RefreshTokenTTL)

	newSess, err := qtx.CreateAuthSession(ctx, db.CreateAuthSessionParams{
		UserID:           u.ID,
		RefreshTokenHash: newRefreshHash,
		ExpiresAt:        refreshExp,
	})
	if err != nil {
		return AuthResponse{}, err
	}

	accessToken, accessExp, err := s.tokens.GenerateAccessToken(newSess.ID, u.ID, u.CompanyID, u.Role, u.MustChangePassword, now)
	if err != nil {
		return AuthResponse{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return AuthResponse{}, err
	}

	userDTO := mapUserRowToDTO(u.ID, u.CompanyID, u.Name, u.Email, u.Role, u.IsActive, u.IsDefaultManager, u.MustChangePassword, u.CreatedAt, u.UpdatedAt)
	userDTO = s.EnrichUserDTO(ctx, userDTO, u.CompanyID, u.ID)

	return AuthResponse{
		AccessToken:           accessToken,
		AccessTokenExpiresAt:  accessExp.Format(time.RFC3339),
		RefreshToken:          newRawRefresh,
		RefreshTokenExpiresAt: refreshExp.Format(time.RFC3339),
		User:                  userDTO,
	}, nil
}

func (s *Service) Logout(ctx context.Context, rawRefreshToken string, sessionID pgtype.UUID) error {
	trimmed := strings.TrimSpace(rawRefreshToken)
	if trimmed == "" && !sessionID.Valid {
		return ErrInvalidRefreshToken
	}
	if trimmed != "" {
		tokenHash := HashRefreshToken(trimmed)
		if err := s.queries.RevokeAuthSessionByTokenHash(ctx, tokenHash); err != nil {
			return err
		}
	}
	if sessionID.Valid {
		if err := s.queries.RevokeAuthSessionByID(ctx, sessionID); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) ChangePassword(ctx context.Context, userID pgtype.UUID, currentPassword, newPassword string) (AuthResponse, error) {
	if currentPassword == "" {
		return AuthResponse{}, ErrInvalidCurrentPassword
	}
	if len(newPassword) < 8 || len([]byte(newPassword)) > 72 {
		return AuthResponse{}, ErrWeakPassword
	}
	if currentPassword == newPassword {
		return AuthResponse{}, ErrSamePassword
	}

	tx, err := s.database.Begin(ctx)
	if err != nil {
		return AuthResponse{}, err
	}
	defer tx.Rollback(ctx)

	qtx := db.New(tx)

	u, err := qtx.GetUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AuthResponse{}, ErrAccountInactive
		}
		return AuthResponse{}, err
	}
	if !u.IsActive || !u.CompanyIsActive {
		return AuthResponse{}, ErrAccountInactive
	}

	if err := ComparePassword(u.PasswordHash, currentPassword); err != nil {
		return AuthResponse{}, ErrInvalidCurrentPassword
	}

	newHash, err := HashPassword(newPassword)
	if err != nil {
		return AuthResponse{}, ErrWeakPassword
	}

	updated, err := qtx.UpdateUserPassword(ctx, db.UpdateUserPasswordParams{
		ID:                 userID,
		PasswordHash:       newHash,
		MustChangePassword: false,
	})
	if err != nil {
		return AuthResponse{}, err
	}

	if err := qtx.RevokeAllUserAuthSessions(ctx, userID); err != nil {
		return AuthResponse{}, err
	}

	now := time.Now().UTC()
	rawRefresh, refreshHash, err := GenerateRefreshToken()
	if err != nil {
		return AuthResponse{}, err
	}
	refreshExp := now.Add(RefreshTokenTTL)

	newSess, err := qtx.CreateAuthSession(ctx, db.CreateAuthSessionParams{
		UserID:           updated.ID,
		RefreshTokenHash: refreshHash,
		ExpiresAt:        refreshExp,
	})
	if err != nil {
		return AuthResponse{}, err
	}

	accessToken, accessExp, err := s.tokens.GenerateAccessToken(newSess.ID, updated.ID, updated.CompanyID, updated.Role, updated.MustChangePassword, now)
	if err != nil {
		return AuthResponse{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return AuthResponse{}, err
	}

	return AuthResponse{
		AccessToken:           accessToken,
		AccessTokenExpiresAt:  accessExp.Format(time.RFC3339),
		RefreshToken:          rawRefresh,
		RefreshTokenExpiresAt: refreshExp.Format(time.RFC3339),
		User:                  mapUserRowToDTO(updated.ID, updated.CompanyID, updated.Name, updated.Email, updated.Role, updated.IsActive, updated.IsDefaultManager, updated.MustChangePassword, updated.CreatedAt, updated.UpdatedAt),
	}, nil
}

func (s *Service) UpdateOwnProfile(ctx context.Context, userID pgtype.UUID, name, email string) (UserDTO, error) {
	trimmedName := strings.TrimSpace(name)
	normalizedEmail := NormalizeAndValidateEmail(email)
	if trimmedName == "" || normalizedEmail == "" {
		return UserDTO{}, ErrInvalidInput
	}

	updated, err := s.queries.UpdateOwnProfile(ctx, db.UpdateOwnProfileParams{
		ID:    userID,
		Name:  trimmedName,
		Email: normalizedEmail,
	})
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return UserDTO{}, ErrEmailAlreadyInUse
		}
		return UserDTO{}, err
	}

	dto := mapUserRowToDTO(updated.ID, updated.CompanyID, updated.Name, updated.Email, updated.Role, updated.IsActive, updated.IsDefaultManager, updated.MustChangePassword, updated.CreatedAt, updated.UpdatedAt)
	return s.EnrichUserDTO(ctx, dto, updated.CompanyID, updated.ID), nil
}

func (s *Service) EnrichUserDTO(ctx context.Context, dto UserDTO, companyID, userID pgtype.UUID) UserDTO {
	if dto.Role != RoleTechnician || !companyID.Valid {
		return dto
	}
	mgrRows, err := s.queries.ListManagersByTechnician(ctx, db.ListManagersByTechnicianParams{
		CompanyID:    companyID,
		TechnicianID: userID,
	})
	if err != nil {
		return dto
	}
	managers := make([]ResponsibleManagerDTO, 0, len(mgrRows))
	for _, m := range mgrRows {
		if !m.IsActive {
			continue
		}
		managers = append(managers, ResponsibleManagerDTO{
			ID:    FormatUUID(m.ID),
			Name:  m.Name,
			Email: m.Email,
		})
	}
	dto.ResponsibleManagers = managers
	return dto
}

func NormalizeAndValidateEmail(raw string) string {
	trimmed := strings.ToLower(strings.TrimSpace(raw))
	if trimmed == "" || strings.ContainsAny(trimmed, " \t\r\n") {
		return ""
	}
	addr, err := mail.ParseAddress(trimmed)
	if err != nil || addr.Address != trimmed {
		return ""
	}
	return trimmed
}

func mapUserRowToDTO(
	id pgtype.UUID,
	companyID pgtype.UUID,
	name, email, role string,
	isActive, isDefaultManager, mustChangePassword bool,
	createdAt, updatedAt time.Time,
) UserDTO {
	var compID *string
	if companyID.Valid {
		s := FormatUUID(companyID)
		compID = &s
	}
	return UserDTO{
		ID:                 FormatUUID(id),
		CompanyID:          compID,
		Name:               name,
		Email:              email,
		Role:               role,
		IsActive:           isActive,
		IsDefaultManager:   isDefaultManager,
		MustChangePassword: mustChangePassword,
		CreatedAt:          createdAt.UTC().Format(time.RFC3339),
		UpdatedAt:          updatedAt.UTC().Format(time.RFC3339),
	}
}
