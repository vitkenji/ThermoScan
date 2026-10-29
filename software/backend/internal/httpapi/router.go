package httpapi

import (
	"context"
	"net/http"
	"time"

	"backend/internal/auth"
	"backend/internal/company"
	"backend/internal/httpjson"
	"backend/internal/user"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type DBPinger interface {
	Ping(ctx context.Context) error
}

type Dependencies struct {
	Pinger         DBPinger
	AuthHandler    *auth.Handler
	CompanyHandler *company.Handler
	UserHandler    *user.Handler
}

func NewRouter(deps Dependencies) http.Handler {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	healthHandler := func(w http.ResponseWriter, req *http.Request) {
		ctx, cancel := context.WithTimeout(req.Context(), 3*time.Second)
		defer cancel()

		if deps.Pinger != nil {
			if err := deps.Pinger.Ping(ctx); err != nil {
				httpjson.WriteJSON(w, http.StatusServiceUnavailable, map[string]string{
					"status": "unavailable",
				})
				return
			}
		}

		httpjson.WriteJSON(w, http.StatusOK, map[string]string{
			"status": "ok",
		})
	}

	r.Get("/health", healthHandler)

	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/health", healthHandler)

		if deps.AuthHandler != nil {
			deps.AuthHandler.RegisterRoutes(r)
		}
		if deps.CompanyHandler != nil {
			deps.CompanyHandler.RegisterRoutes(r)
		}
		if deps.UserHandler != nil {
			deps.UserHandler.RegisterRoutes(r)
		}
	})

	return r
}
