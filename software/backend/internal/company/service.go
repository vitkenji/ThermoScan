package company

import (
	"context"
	"errors"
	"strings"
	"time"

	"backend/internal/auth"
	"backend/internal/db"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

var (
	ErrInvalidInput     = errors.New("invalid input")
	ErrNotFound         = errors.New("company or manager not found")
	ErrEmailConflict    = errors.New("manager email is already in use")
	ErrTargetNotManager = errors.New("target user is not a manager")
)

type CompanyDTO struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Address   *string `json:"address"`
	IsActive  bool    `json:"is_active"`
	CreatedAt string  `json:"created_at"`
	UpdatedAt string  `json:"updated_at"`
}

type CompanyDetailsDTO struct {
	Company  CompanyDTO     `json:"company"`
	Managers []auth.UserDTO `json:"managers"`
}

type CreateCompanyInput struct {
	Name         string
	Address      *string
	ManagerName  string
	ManagerEmail string
}

type CreateCompanyResult struct {
	Company           CompanyDTO   `json:"company"`
	DefaultManager    auth.UserDTO `json:"default_manager"`
	TemporaryPassword string       `json:"temporary_password"`
}

type ResetPasswordResult struct {
	User              auth.UserDTO `json:"user"`
	TemporaryPassword string       `json:"temporary_password"`
}

type Service struct {
	database auth.DB
	queries  *db.Queries
}

func NewService(database auth.DB) *Service {
	return &Service{
		database: database,
		queries:  db.New(database),
	}
}

func (s *Service) CreateCompany(ctx context.Context, in CreateCompanyInput) (CreateCompanyResult, error) {
	companyName := strings.TrimSpace(in.Name)
	managerName := strings.TrimSpace(in.ManagerName)
	managerEmail := auth.NormalizeAndValidateEmail(in.ManagerEmail)

	if companyName == "" || managerName == "" || managerEmail == "" {
		return CreateCompanyResult{}, ErrInvalidInput
	}

	var addr pgtype.Text
	if in.Address != nil {
		trimmedAddr := strings.TrimSpace(*in.Address)
		if trimmedAddr != "" {
			addr = pgtype.Text{String: trimmedAddr, Valid: true}
		}
	}

	tempPass, err := auth.GenerateTemporaryPassword()
	if err != nil {
		return CreateCompanyResult{}, err
	}
	passHash, err := auth.HashPassword(tempPass)
	if err != nil {
		return CreateCompanyResult{}, err
	}

	tx, err := s.database.Begin(ctx)
	if err != nil {
		return CreateCompanyResult{}, err
	}
	defer tx.Rollback(ctx)

	qtx := db.New(tx)

	comp, err := qtx.CreateCompany(ctx, db.CreateCompanyParams{
		Name:    companyName,
		Address: addr,
	})
	if err != nil {
		return CreateCompanyResult{}, err
	}

	mgr, err := qtx.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          comp.ID,
		Name:               managerName,
		Email:              managerEmail,
		PasswordHash:       passHash,
		Role:               auth.RoleManager,
		IsActive:           true,
		IsDefaultManager:   true,
		MustChangePassword: true,
	})
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return CreateCompanyResult{}, ErrEmailConflict
		}
		return CreateCompanyResult{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return CreateCompanyResult{}, err
	}

	compIDStr := auth.FormatUUID(comp.ID)
	return CreateCompanyResult{
		Company: mapCompanyToDTO(comp),
		DefaultManager: auth.UserDTO{
			ID:                 auth.FormatUUID(mgr.ID),
			CompanyID:          &compIDStr,
			Name:               mgr.Name,
			Email:              mgr.Email,
			Role:               mgr.Role,
			IsActive:           mgr.IsActive,
			IsDefaultManager:   mgr.IsDefaultManager,
			MustChangePassword: mgr.MustChangePassword,
			CreatedAt:          mgr.CreatedAt.UTC().Format(time.RFC3339),
			UpdatedAt:          mgr.UpdatedAt.UTC().Format(time.RFC3339),
		},
		TemporaryPassword: tempPass,
	}, nil
}

func (s *Service) ListCompanies(ctx context.Context, limit, offset int32) ([]CompanyDTO, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	rows, err := s.queries.ListCompanies(ctx, db.ListCompaniesParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, err
	}

	out := make([]CompanyDTO, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapCompanyToDTO(r))
	}
	return out, nil
}

func (s *Service) GetCompany(ctx context.Context, companyID pgtype.UUID) (CompanyDetailsDTO, error) {
	comp, err := s.queries.GetCompanyByID(ctx, companyID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CompanyDetailsDTO{}, ErrNotFound
		}
		return CompanyDetailsDTO{}, err
	}

	mgrRows, err := s.queries.ListUsersByCompany(ctx, db.ListUsersByCompanyParams{
		CompanyID: companyID,
		Limit:     100,
		Offset:    0,
		Role:      pgtype.Text{String: auth.RoleManager, Valid: true},
	})
	if err != nil {
		return CompanyDetailsDTO{}, err
	}

	compIDStr := auth.FormatUUID(comp.ID)
	managers := make([]auth.UserDTO, 0, len(mgrRows))
	for _, m := range mgrRows {
		cID := compIDStr
		managers = append(managers, auth.UserDTO{
			ID:                 auth.FormatUUID(m.ID),
			CompanyID:          &cID,
			Name:               m.Name,
			Email:              m.Email,
			Role:               m.Role,
			IsActive:           m.IsActive,
			IsDefaultManager:   m.IsDefaultManager,
			MustChangePassword: m.MustChangePassword,
			CreatedAt:          m.CreatedAt.UTC().Format(time.RFC3339),
			UpdatedAt:          m.UpdatedAt.UTC().Format(time.RFC3339),
		})
	}

	return CompanyDetailsDTO{
		Company:  mapCompanyToDTO(comp),
		Managers: managers,
	}, nil
}

func (s *Service) SetCompanyStatus(ctx context.Context, companyID pgtype.UUID, isActive bool) (CompanyDTO, error) {
	comp, err := s.queries.SetCompanyActiveStatus(ctx, db.SetCompanyActiveStatusParams{
		ID:       companyID,
		IsActive: isActive,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CompanyDTO{}, ErrNotFound
		}
		return CompanyDTO{}, err
	}
	return mapCompanyToDTO(comp), nil
}

func (s *Service) ResetManagerPassword(ctx context.Context, companyID, managerID pgtype.UUID) (ResetPasswordResult, error) {
	tx, err := s.database.Begin(ctx)
	if err != nil {
		return ResetPasswordResult{}, err
	}
	defer tx.Rollback(ctx)

	qtx := db.New(tx)

	target, err := qtx.GetCompanyUserByIDForUpdate(ctx, db.GetCompanyUserByIDForUpdateParams{
		CompanyID: companyID,
		ID:        managerID,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ResetPasswordResult{}, ErrNotFound
		}
		return ResetPasswordResult{}, err
	}

	if target.Role != auth.RoleManager {
		return ResetPasswordResult{}, ErrTargetNotManager
	}

	tempPass, err := auth.GenerateTemporaryPassword()
	if err != nil {
		return ResetPasswordResult{}, err
	}
	passHash, err := auth.HashPassword(tempPass)
	if err != nil {
		return ResetPasswordResult{}, err
	}

	updated, err := qtx.UpdateUserPassword(ctx, db.UpdateUserPasswordParams{
		ID:                 target.ID,
		PasswordHash:       passHash,
		MustChangePassword: true,
	})
	if err != nil {
		return ResetPasswordResult{}, err
	}

	if err := qtx.RevokeAllUserAuthSessions(ctx, target.ID); err != nil {
		return ResetPasswordResult{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return ResetPasswordResult{}, err
	}

	compIDStr := auth.FormatUUID(companyID)
	return ResetPasswordResult{
		User: auth.UserDTO{
			ID:                 auth.FormatUUID(updated.ID),
			CompanyID:          &compIDStr,
			Name:               updated.Name,
			Email:              updated.Email,
			Role:               updated.Role,
			IsActive:           updated.IsActive,
			IsDefaultManager:   updated.IsDefaultManager,
			MustChangePassword: updated.MustChangePassword,
			CreatedAt:          updated.CreatedAt.UTC().Format(time.RFC3339),
			UpdatedAt:          updated.UpdatedAt.UTC().Format(time.RFC3339),
		},
		TemporaryPassword: tempPass,
	}, nil
}

func mapCompanyToDTO(c db.Company) CompanyDTO {
	var addr *string
	if c.Address.Valid {
		s := c.Address.String
		addr = &s
	}
	return CompanyDTO{
		ID:        auth.FormatUUID(c.ID),
		Name:      c.Name,
		Address:   addr,
		IsActive:  c.IsActive,
		CreatedAt: c.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt: c.UpdatedAt.UTC().Format(time.RFC3339),
	}
}
