package httpapi_test

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
	"backend/internal/company"
	"backend/internal/db"
	"backend/internal/httpapi"
	"backend/internal/user"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

func testDBURL() string {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	return "postgres://termoscan:termoscan@localhost:5432/termoscan?sslmode=disable"
}

func TestCompaniesAndUsersIntegration(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
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

	// Create an active system_admin with password already changed
	adminPass := "AdminStrongPass#2026"
	adminHash, err := auth.HashPassword(adminPass)
	if err != nil {
		t.Fatalf("HashPassword failed: %v", err)
	}

	_, err = q.CreateUser(ctx, db.CreateUserParams{
		CompanyID:          pgtype.UUID{Valid: false},
		Name:               "Test System Admin",
		Email:              "sysadmin.test@termoscan.local",
		PasswordHash:       adminHash,
		Role:               auth.RoleSystemAdmin,
		IsActive:           true,
		IsDefaultManager:   false,
		MustChangePassword: false,
	})
	if err != nil {
		t.Fatalf("CreateUser (system_admin) failed: %v", err)
	}

	tokens := auth.NewTokenManager("test-jwt-secret-key-phase1-integration")
	authSvc := auth.NewService(tx, tokens)
	compSvc := company.NewService(tx)
	userSvc := user.NewService(tx)

	router := httpapi.NewRouter(httpapi.Dependencies{
		AuthHandler:    auth.NewHandler(authSvc, q, tokens),
		CompanyHandler: company.NewHandler(compSvc, q, tokens),
		UserHandler:    user.NewHandler(userSvc, q, tokens),
	})

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

	loginAndUnlock := func(email, tempPass, newPass string) auth.AuthResponse {
		rec := doJSON(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
			"email":    email,
			"password": tempPass,
		})
		if rec.Code != http.StatusOK {
			t.Fatalf("login(%s) failed (%d): %s", email, rec.Code, rec.Body.String())
		}
		var loginResp auth.AuthResponse
		_ = json.Unmarshal(rec.Body.Bytes(), &loginResp)

		if loginResp.User.MustChangePassword {
			rec = doJSON(http.MethodPost, "/api/v1/auth/change-password", loginResp.AccessToken, map[string]string{
				"current_password": tempPass,
				"new_password":     newPass,
			})
			if rec.Code != http.StatusOK {
				t.Fatalf("change-password(%s) failed (%d): %s", email, rec.Code, rec.Body.String())
			}
			_ = json.Unmarshal(rec.Body.Bytes(), &loginResp)
		}
		return loginResp
	}

	// 1. Login as system_admin
	adminAuth := loginAndUnlock("sysadmin.test@termoscan.local", adminPass, adminPass)

	// 2. System Admin creates Company A + Default Manager A
	rec := doJSON(http.MethodPost, "/api/v1/companies", adminAuth.AccessToken, map[string]any{
		"name":          "Solar Alpha Ltda",
		"address":       "Rua A, 100",
		"manager_name":  "Manager Alpha",
		"manager_email": "mgr@alpha.local",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 creating Company A, got %d: %s", rec.Code, rec.Body.String())
	}
	var compAResp company.CreateCompanyResult
	_ = json.Unmarshal(rec.Body.Bytes(), &compAResp)

	// 3. System Admin creates Company B + Default Manager B
	rec = doJSON(http.MethodPost, "/api/v1/companies", adminAuth.AccessToken, map[string]any{
		"name":          "Solar Beta S.A.",
		"address":       "Rua B, 200",
		"manager_name":  "Manager Beta",
		"manager_email": "mgr@beta.local",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 creating Company B, got %d: %s", rec.Code, rec.Body.String())
	}
	var compBResp company.CreateCompanyResult
	_ = json.Unmarshal(rec.Body.Bytes(), &compBResp)

	// 4. System Admin is denied access to company operational user endpoints (/api/v1/users)
	rec = doJSON(http.MethodGet, "/api/v1/users", adminAuth.AccessToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 when system_admin accesses /api/v1/users, got %d", rec.Code)
	}

	// 5. Manager Alpha logs in and changes temporary password
	mgrAPass := "AlphaMgr#2026"
	mgrAAuth := loginAndUnlock("mgr@alpha.local", compAResp.TemporaryPassword, mgrAPass)

	// Manager Beta logs in and changes temporary password
	mgrBPass := "BetaMgr#2026"
	mgrBAuth := loginAndUnlock("mgr@beta.local", compBResp.TemporaryPassword, mgrBPass)

	// 6. Manager Alpha cannot access /api/v1/companies (System Admin only)
	rec = doJSON(http.MethodGet, "/api/v1/companies", mgrAAuth.AccessToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 when manager accesses /api/v1/companies, got %d", rec.Code)
	}

	// 7. Manager Alpha creates an additional Manager, a Technician, and a Client in Company A
	rec = doJSON(http.MethodPost, "/api/v1/users", mgrAAuth.AccessToken, map[string]any{
		"name":  "Second Manager Alpha",
		"email": "mgr2@alpha.local",
		"role":  "manager",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 creating additional manager, got %d: %s", rec.Code, rec.Body.String())
	}
	var mgr2Resp user.CreateUserResult
	_ = json.Unmarshal(rec.Body.Bytes(), &mgr2Resp)

	// Creating Technician without manager_ids must fail with 400
	rec = doJSON(http.MethodPost, "/api/v1/users", mgrAAuth.AccessToken, map[string]any{
		"name":  "Tech Invalid",
		"email": "tech.invalid@alpha.local",
		"role":  "technician",
	})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 creating technician without manager_ids, got %d", rec.Code)
	}

	// Creating Technician linked to Manager from Company B must fail with 400 (cross-tenant protection!)
	rec = doJSON(http.MethodPost, "/api/v1/users", mgrAAuth.AccessToken, map[string]any{
		"name":        "Tech CrossTenant",
		"email":       "tech.cross@alpha.local",
		"role":        "technician",
		"manager_ids": []string{compBResp.DefaultManager.ID},
	})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 creating technician with manager from another company, got %d", rec.Code)
	}

	// Creating Technician linked to Manager Alpha succeeds
	rec = doJSON(http.MethodPost, "/api/v1/users", mgrAAuth.AccessToken, map[string]any{
		"name":        "Tech Alpha One",
		"email":       "tech1@alpha.local",
		"role":        "technician",
		"manager_ids": []string{compAResp.DefaultManager.ID},
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 creating technician, got %d: %s", rec.Code, rec.Body.String())
	}
	var techResp user.CreateUserResult
	_ = json.Unmarshal(rec.Body.Bytes(), &techResp)

	// Creating Client in Company A succeeds
	rec = doJSON(http.MethodPost, "/api/v1/users", mgrAAuth.AccessToken, map[string]any{
		"name":  "Client Alpha One",
		"email": "client1@alpha.local",
		"role":  "client",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 creating client, got %d: %s", rec.Code, rec.Body.String())
	}

	// 8. Cross-company isolation: Manager Beta cannot view, deactivate, or reset Tech Alpha One
	rec = doJSON(http.MethodGet, "/api/v1/users/"+techResp.User.ID, mgrBAuth.AccessToken, nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 when Manager B reads Company A user, got %d", rec.Code)
	}

	rec = doJSON(http.MethodPost, "/api/v1/users/"+techResp.User.ID+"/reset-password", mgrBAuth.AccessToken, nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 when Manager B resets Company A user password, got %d", rec.Code)
	}

	// 9. Manager Alpha cannot deactivate or reset password of another Manager in Company A (Rule 6 & 8)
	rec = doJSON(http.MethodPatch, "/api/v1/users/"+mgr2Resp.User.ID+"/status", mgrAAuth.AccessToken, map[string]any{
		"is_active": false,
	})
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 when Manager tries to deactivate another Manager, got %d", rec.Code)
	}

	rec = doJSON(http.MethodPost, "/api/v1/users/"+mgr2Resp.User.ID+"/reset-password", mgrAAuth.AccessToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 when Manager tries to reset another Manager's password, got %d", rec.Code)
	}

	// 10. Manager Alpha CAN reset password and deactivate Technician in Company A
	rec = doJSON(http.MethodPost, "/api/v1/users/"+techResp.User.ID+"/reset-password", mgrAAuth.AccessToken, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 when Manager resets Technician password, got %d: %s", rec.Code, rec.Body.String())
	}

	rec = doJSON(http.MethodPatch, "/api/v1/users/"+techResp.User.ID+"/status", mgrAAuth.AccessToken, map[string]any{
		"is_active": false,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 when Manager deactivates Technician, got %d: %s", rec.Code, rec.Body.String())
	}

	// 11. System Admin CAN reset Manager Alpha's password, but CANNOT reset Technician's password
	rec = doJSON(http.MethodPost, "/api/v1/companies/"+compAResp.Company.ID+"/managers/"+techResp.User.ID+"/reset-password", adminAuth.AccessToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 when System Admin tries to reset Technician password, got %d", rec.Code)
	}

	rec = doJSON(http.MethodPost, "/api/v1/companies/"+compAResp.Company.ID+"/managers/"+compAResp.DefaultManager.ID+"/reset-password", adminAuth.AccessToken, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 when System Admin resets Manager password, got %d: %s", rec.Code, rec.Body.String())
	}
}
