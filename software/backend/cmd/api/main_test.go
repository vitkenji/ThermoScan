package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"backend/internal/httpapi"
)

type mockPinger struct {
	err error
}

func (m mockPinger) Ping(ctx context.Context) error {
	return m.err
}

func TestHealthEndpoint(t *testing.T) {
	t.Run("returns 200 OK when DB is reachable", func(t *testing.T) {
		router := httpapi.NewRouter(httpapi.Dependencies{Pinger: mockPinger{err: nil}})
		for _, path := range []string{"/health", "/api/v1/health"} {
			req := httptest.NewRequest(http.MethodGet, path, nil)
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)

			if rec.Code != http.StatusOK {
				t.Fatalf("%s: expected status 200, got %d", path, rec.Code)
			}
		}
	})

	t.Run("returns 503 Service Unavailable when DB ping fails", func(t *testing.T) {
		router := httpapi.NewRouter(httpapi.Dependencies{Pinger: mockPinger{err: errors.New("db connection lost")}})
		req := httptest.NewRequest(http.MethodGet, "/health", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("expected status 503, got %d", rec.Code)
		}
	})
}
