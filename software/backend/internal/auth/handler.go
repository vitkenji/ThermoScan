package auth

import (
	"errors"
	"net/http"
	"strings"

	"backend/internal/db"
	"backend/internal/httpjson"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type Handler struct {
	service *Service
	queries *db.Queries
	tokens  *TokenManager
}

func NewHandler(service *Service, queries *db.Queries, tokens *TokenManager) *Handler {
	return &Handler{
		service: service,
		queries: queries,
		tokens:  tokens,
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/auth", func(r chi.Router) {
		r.Post("/login", h.handleLogin)
		r.Post("/refresh", h.handleRefresh)
		r.Post("/logout", h.handleLogout)

		r.Group(func(r chi.Router) {
			r.Use(Authenticate(h.queries, h.tokens))

			// Allowed even when must_change_password == true
			r.Get("/me", h.handleGetMe)
			r.Post("/change-password", h.handleChangePassword)

			// Requires password to have been changed from temporary password
			r.Group(func(r chi.Router) {
				r.Use(RequirePasswordChanged)
				r.Patch("/me", h.handleUpdateOwnProfile)
			})
		})
	})
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *Handler) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid request payload", "INVALID_PAYLOAD")
		return
	}

	resp, err := h.service.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidCredentials):
			httpjson.WriteError(w, http.StatusUnauthorized, "invalid email or password", "INVALID_CREDENTIALS")
		case errors.Is(err, ErrAccountInactive):
			httpjson.WriteError(w, http.StatusForbidden, "this account is inactive. Contact your company Manager", "ACCOUNT_INACTIVE")
		default:
			httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		}
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, resp)
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid request payload", "INVALID_PAYLOAD")
		return
	}

	resp, err := h.service.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		if errors.Is(err, ErrInvalidRefreshToken) || errors.Is(err, ErrAccountInactive) {
			httpjson.WriteError(w, http.StatusUnauthorized, "invalid or expired refresh token", "INVALID_REFRESH_TOKEN")
			return
		}
		httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, resp)
}

type logoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) handleLogout(w http.ResponseWriter, r *http.Request) {
	var req logoutRequest
	if r.ContentLength != 0 {
		if err := httpjson.DecodeJSON(r, &req); err != nil {
			httpjson.WriteError(w, http.StatusBadRequest, "invalid request payload", "INVALID_PAYLOAD")
			return
		}
	}

	var sessionID pgtype.UUID
	if authHeader := strings.TrimSpace(r.Header.Get("Authorization")); authHeader != "" {
		if scheme, tokenStr, ok := strings.Cut(authHeader, " "); ok && strings.EqualFold(scheme, "Bearer") {
			if _, _, sid, err := h.tokens.ParseAccessToken(strings.TrimSpace(tokenStr)); err == nil {
				sessionID = sid
			}
		}
	}

	if err := h.service.Logout(r.Context(), req.RefreshToken, sessionID); err != nil {
		if errors.Is(err, ErrInvalidRefreshToken) {
			httpjson.WriteError(w, http.StatusBadRequest, "refresh_token or Bearer token is required", "INVALID_PAYLOAD")
			return
		}
		httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, map[string]string{
		"message": "logged out successfully",
	})
}

func (h *Handler) handleGetMe(w http.ResponseWriter, r *http.Request) {
	principal, ok := PrincipalFromContext(r.Context())
	if !ok {
		httpjson.WriteError(w, http.StatusUnauthorized, "authentication required", "UNAUTHORIZED")
		return
	}

	dto := h.service.EnrichUserDTO(r.Context(), principal.ToDTO(), principal.CompanyID, principal.ID)
	httpjson.WriteJSON(w, http.StatusOK, dto)
}

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

func (h *Handler) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	principal, ok := PrincipalFromContext(r.Context())
	if !ok {
		httpjson.WriteError(w, http.StatusUnauthorized, "authentication required", "UNAUTHORIZED")
		return
	}

	var req changePasswordRequest
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid request payload", "INVALID_PAYLOAD")
		return
	}

	resp, err := h.service.ChangePassword(r.Context(), principal.ID, req.CurrentPassword, req.NewPassword)
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidCurrentPassword):
			httpjson.WriteError(w, http.StatusUnauthorized, "current password is incorrect", "INVALID_CURRENT_PASSWORD")
		case errors.Is(err, ErrWeakPassword):
			httpjson.WriteError(w, http.StatusBadRequest, "new password must be between 8 and 72 bytes", "WEAK_PASSWORD")
		case errors.Is(err, ErrSamePassword):
			httpjson.WriteError(w, http.StatusBadRequest, "new password must be different from current password", "SAME_PASSWORD")
		case errors.Is(err, ErrAccountInactive):
			httpjson.WriteError(w, http.StatusUnauthorized, "account is inactive", "UNAUTHORIZED")
		default:
			httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		}
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, resp)
}

type updateOwnProfileRequest struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

func (h *Handler) handleUpdateOwnProfile(w http.ResponseWriter, r *http.Request) {
	principal, ok := PrincipalFromContext(r.Context())
	if !ok {
		httpjson.WriteError(w, http.StatusUnauthorized, "authentication required", "UNAUTHORIZED")
		return
	}

	var req updateOwnProfileRequest
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid request payload", "INVALID_PAYLOAD")
		return
	}

	updated, err := h.service.UpdateOwnProfile(r.Context(), principal.ID, req.Name, req.Email)
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidInput):
			httpjson.WriteError(w, http.StatusBadRequest, "valid name and email are required", "INVALID_INPUT")
		case errors.Is(err, ErrEmailAlreadyInUse):
			httpjson.WriteError(w, http.StatusConflict, "email is already in use", "EMAIL_CONFLICT")
		default:
			httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		}
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, updated)
}
