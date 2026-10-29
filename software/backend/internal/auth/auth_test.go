package auth_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"backend/internal/auth"
	"backend/internal/db"
	"backend/internal/httpapi"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

func testDBURL() string {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	return "postgres://thermoscan:thermoscan@localhost:5432/thermoscan?sslmode=disable"
}

func TestAuthFlowIntegration(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
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

	// Create company + manager with temporary password (must_change_password = true)
	company, err := q.CreateCompany(ctx, db.CreateCompanyParams{
		Name:    "AuthTest Solar",
		Address: pgtype.Text{String: "Rua XV, 100", Valid: true},
	})
	if err != nil {
		t.Fatalf("CreateCompany failed: %v", err)
	}

	tempPass := "TempPass#12345"
	hash, err := auth.HashPassword(tempPass)
	if err != nil {
		t.Fatalf("HashPassword failed: %v", err)
	}

	_, err = q.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          company.ID,
		Name:               "Alice Manager",
		Email:              "alice@authtest.local",
		PasswordHash:       hash,
		Role:               auth.RoleManager,
		IsActive:           true,
		IsDefaultManager:   true,
		MustChangePassword: true,
	})
	if err != nil {
		t.Fatalf("CreateUser failed: %v", err)
	}

	tokens := auth.NewTokenManager("test-jwt-secret-key-1234567890")
	svc := auth.NewService(tx, tokens)
	handler := auth.NewHandler(svc, q, tokens)
	router := httpapi.NewRouter(httpapi.Dependencies{AuthHandler: handler})

	doJSON := func(method, path, bearer string, body any) *httptest.ResponseRecorder {
		var buf bytes.Buffer
		if body != nil {
			if err := json.NewEncoder(&buf).Encode(body); err != nil {
				t.Fatalf("encode body: %v", err)
			}
		}
		req := httptest.NewRequest(method, path, &buf)
		req.Header.Set("Content-Type", "application/json")
		if bearer != "" {
			req.Header.Set("Authorization", "Bearer "+bearer)
		}
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		return rec
	}

	// 1. Invalid password returns 401
	rec := doJSON(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"email":    "alice@authtest.local",
		"password": "wrong-password",
	})
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 on wrong password, got %d: %s", rec.Code, rec.Body.String())
	}

	// 2. Valid login with temporary password succeeds and indicates must_change_password = true
	rec = doJSON(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"email":    "  ALICE@AUTHTEST.LOCAL ",
		"password": tempPass,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 on valid login, got %d: %s", rec.Code, rec.Body.String())
	}

	var loginResp auth.AuthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &loginResp); err != nil {
		t.Fatalf("decode login response: %v", err)
	}
	if !loginResp.User.MustChangePassword {
		t.Fatalf("expected MustChangePassword=true on initial login")
	}

	// 3. While MustChangePassword=true, PATCH /api/v1/auth/me is blocked with 403 PASSWORD_CHANGE_REQUIRED
	rec = doJSON(http.MethodPatch, "/api/v1/auth/me", loginResp.AccessToken, map[string]string{
		"name":  "Alice Updated",
		"email": "alice@authtest.local",
	})
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 when must_change_password=true, got %d: %s", rec.Code, rec.Body.String())
	}

	// 4. GET /api/v1/auth/me is allowed while MustChangePassword=true
	rec = doJSON(http.MethodGet, "/api/v1/auth/me", loginResp.AccessToken, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 on GET /me, got %d: %s", rec.Code, rec.Body.String())
	}

	// 5. Change password succeeds, revokes old refresh token, and clears must_change_password
	newPass := "NewStrongPass#2026"
	rec = doJSON(http.MethodPost, "/api/v1/auth/change-password", loginResp.AccessToken, map[string]string{
		"current_password": tempPass,
		"new_password":     newPass,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 on change-password, got %d: %s", rec.Code, rec.Body.String())
	}

	var changeResp auth.AuthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &changeResp); err != nil {
		t.Fatalf("decode change-password response: %v", err)
	}
	if changeResp.User.MustChangePassword {
		t.Fatalf("expected MustChangePassword=false after password change")
	}

	// 6. Old refresh token must be rejected because sessions were revoked on password change
	rec = doJSON(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refresh_token": loginResp.RefreshToken,
	})
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 when using revoked refresh token, got %d", rec.Code)
	}

	// 7. New refresh token rotates cleanly
	rec = doJSON(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refresh_token": changeResp.RefreshToken,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 on refresh with new token, got %d: %s", rec.Code, rec.Body.String())
	}
	var refreshedResp auth.AuthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &refreshedResp); err != nil {
		t.Fatalf("decode refresh response: %v", err)
	}

	// 8. PATCH /api/v1/auth/me now succeeds
	rec = doJSON(http.MethodPatch, "/api/v1/auth/me", refreshedResp.AccessToken, map[string]string{
		"name":  "Alice Renamed",
		"email": "alice.renamed@authtest.local",
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 on PATCH /me, got %d: %s", rec.Code, rec.Body.String())
	}

	// 9. Logout revokes the rotated refresh token AND immediately invalidates the access token
	rec = doJSON(http.MethodPost, "/api/v1/auth/logout", "", map[string]string{
		"refresh_token": refreshedResp.RefreshToken,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 on logout, got %d: %s", rec.Code, rec.Body.String())
	}

	rec = doJSON(http.MethodGet, "/api/v1/auth/me", refreshedResp.AccessToken, nil)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 when using access token of a logged-out session, got %d: %s", rec.Code, rec.Body.String())
	}

	// 10. Deactivated user login with valid password returns 403 ACCOUNT_INACTIVE
	_, err = q.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          company.ID,
		Name:               "Inactive Tech",
		Email:              "inactive.tech@authtest.local",
		PasswordHash:       hash,
		Role:               auth.RoleTechnician,
		IsActive:           false,
		IsDefaultManager:   false,
		MustChangePassword: false,
	})
	if err != nil {
		t.Fatalf("CreateUser (inactive tech) failed: %v", err)
	}

	rec = doJSON(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"email":    "inactive.tech@authtest.local",
		"password": tempPass,
	})
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 ACCOUNT_INACTIVE on login for deactivated user, got %d: %s", rec.Code, rec.Body.String())
	}
}
