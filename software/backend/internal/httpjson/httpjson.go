package httpjson

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
)

type ErrorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code,omitempty"`
}

func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func WriteError(w http.ResponseWriter, status int, message string, code ...string) {
	resp := ErrorResponse{Error: message}
	if len(code) > 0 {
		resp.Code = code[0]
	}
	WriteJSON(w, status, resp)
}

func DecodeJSON(r *http.Request, dst any) error {
	const maxBodyBytes = 1 << 20 // 1 MB
	body := http.MaxBytesReader(nil, r.Body, maxBodyBytes)
	defer body.Close()

	dec := json.NewDecoder(body)
	dec.DisallowUnknownFields()

	if err := dec.Decode(dst); err != nil {
		return err
	}
	if err := dec.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return errors.New("request body must contain a single JSON object")
	}
	return nil
}
