package company

import (
	"errors"
	"net/http"
	"strconv"

	"backend/internal/auth"
	"backend/internal/db"
	"backend/internal/httpjson"

	"github.com/go-chi/chi/v5"
)

type Handler struct {
	service *Service
	queries *db.Queries
	tokens  *auth.TokenManager
}

func NewHandler(service *Service, queries *db.Queries, tokens *auth.TokenManager) *Handler {
	return &Handler{
		service: service,
		queries: queries,
		tokens:  tokens,
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/companies", func(r chi.Router) {
		r.Use(auth.Authenticate(h.queries, h.tokens))
		r.Use(auth.RequirePasswordChanged)
		r.Use(auth.RequireRoles(auth.RoleSystemAdmin))

		r.Post("/", h.handleCreateCompany)
		r.Get("/", h.handleListCompanies)
		r.Get("/{companyID}", h.handleGetCompany)
		r.Patch("/{companyID}/status", h.handleSetCompanyStatus)
		r.Post("/{companyID}/managers/{managerID}/reset-password", h.handleResetManagerPassword)
	})
}

type createCompanyRequest struct {
	Name         string  `json:"name"`
	Address      *string `json:"address"`
	ManagerName  string  `json:"manager_name"`
	ManagerEmail string  `json:"manager_email"`
}

func (h *Handler) handleCreateCompany(w http.ResponseWriter, r *http.Request) {
	var req createCompanyRequest
	if err := httpjson.DecodeJSON(r, &req); err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid request payload", "INVALID_PAYLOAD")
		return
	}

	res, err := h.service.CreateCompany(r.Context(), CreateCompanyInput{
		Name:         req.Name,
		Address:      req.Address,
		ManagerName:  req.ManagerName,
		ManagerEmail: req.ManagerEmail,
	})
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidInput):
			httpjson.WriteError(w, http.StatusBadRequest, "company name, manager_name, and valid manager_email are required", "INVALID_INPUT")
		case errors.Is(err, ErrEmailConflict):
			httpjson.WriteError(w, http.StatusConflict, "manager email is already in use", "EMAIL_CONFLICT")
		default:
			httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		}
		return
	}

	httpjson.WriteJSON(w, http.StatusCreated, res)
}

func (h *Handler) handleListCompanies(w http.ResponseWriter, r *http.Request) {
	limit := parsePositiveInt32(r.URL.Query().Get("limit"), 50)
	offset := parsePositiveInt32(r.URL.Query().Get("offset"), 0)

	companies, err := h.service.ListCompanies(r.Context(), limit, offset)
	if err != nil {
		httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, map[string]any{
		"companies": companies,
	})
}

func (h *Handler) handleGetCompany(w http.ResponseWriter, r *http.Request) {
	companyID, err := auth.ParseUUID(chi.URLParam(r, "companyID"))
	if err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid company ID", "INVALID_ID")
		return
	}

	res, err := h.service.GetCompany(r.Context(), companyID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpjson.WriteError(w, http.StatusNotFound, "company not found", "NOT_FOUND")
			return
		}
		httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, res)
}

type setCompanyStatusRequest struct {
	IsActive *bool `json:"is_active"`
}

func (h *Handler) handleSetCompanyStatus(w http.ResponseWriter, r *http.Request) {
	companyID, err := auth.ParseUUID(chi.URLParam(r, "companyID"))
	if err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid company ID", "INVALID_ID")
		return
	}

	var req setCompanyStatusRequest
	if err := httpjson.DecodeJSON(r, &req); err != nil || req.IsActive == nil {
		httpjson.WriteError(w, http.StatusBadRequest, "is_active boolean is required", "INVALID_PAYLOAD")
		return
	}

	comp, err := h.service.SetCompanyStatus(r.Context(), companyID, *req.IsActive)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpjson.WriteError(w, http.StatusNotFound, "company not found", "NOT_FOUND")
			return
		}
		httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, comp)
}

func (h *Handler) handleResetManagerPassword(w http.ResponseWriter, r *http.Request) {
	companyID, err := auth.ParseUUID(chi.URLParam(r, "companyID"))
	if err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid company ID", "INVALID_ID")
		return
	}

	managerID, err := auth.ParseUUID(chi.URLParam(r, "managerID"))
	if err != nil {
		httpjson.WriteError(w, http.StatusBadRequest, "invalid manager ID", "INVALID_ID")
		return
	}

	res, err := h.service.ResetManagerPassword(r.Context(), companyID, managerID)
	if err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			httpjson.WriteError(w, http.StatusNotFound, "company or manager not found", "NOT_FOUND")
		case errors.Is(err, ErrTargetNotManager):
			httpjson.WriteError(w, http.StatusForbidden, "system_admin can only reset passwords of managers", "FORBIDDEN")
		default:
			httpjson.WriteError(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
		}
		return
	}

	httpjson.WriteJSON(w, http.StatusOK, res)
}

func parsePositiveInt32(s string, defaultVal int32) int32 {
	if s == "" {
		return defaultVal
	}
	v, err := strconv.ParseInt(s, 10, 32)
	if err != nil || v < 0 {
		return defaultVal
	}
	return int32(v)
}
