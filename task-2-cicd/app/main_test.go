package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	mux := setupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rr := httptest.NewRecorder()

	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}

	var res Response
	if err := json.Unmarshal(rr.Body.Bytes(), &res); err != nil {
		t.Fatalf("invalid json response: %v", err)
	}

	if res.Status != "healthy" {
		t.Errorf("expected status 'healthy', got '%s'", res.Status)
	}

	if res.Service != "rova-api" {
		t.Errorf("expected service 'rova-api', got '%s'", res.Service)
	}
}

func TestRootEndpoint(t *testing.T) {
	mux := setupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()

	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}
}

func TestNotFound(t *testing.T) {
	mux := setupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/invalid-path", nil)
	rr := httptest.NewRecorder()

	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", rr.Code)
	}
}
