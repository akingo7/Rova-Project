package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

type Response struct {
	Message string `json:"message,omitempty"`
	Service string `json:"service"`
	Status  string `json:"status"`
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Response{
		Message: "Welcome to Rova API",
		Service: "rova-api",
		Status:  "running",
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(Response{
		Service: "rova-api",
		Status:  "healthy",
	})
}

func setupRoutes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/", rootHandler)
	mux.HandleFunc("/health", healthHandler)
	return mux
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := setupRoutes()
	log.Printf("Starting rova-api on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
