package middleware

import (
	"context"
	"log"
	"net/http"

	"forum/internal/services"
)

type contextKey string

const UserContextKey contextKey = "user"

type AuthMiddleware struct {
	sessionService *services.SessionService
}

func NewAuthMiddleware(sessionService *services.SessionService) *AuthMiddleware {
	return &AuthMiddleware{sessionService: sessionService}
}

// Optional authentication - sets user in context if logged in
func (m *AuthMiddleware) OptionalAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("session_token")
		if err != nil {
			// No session cookie, continue without user
			next.ServeHTTP(w, r)
			return
		}

		user, err := m.sessionService.GetUserByToken(cookie.Value)
		if err != nil {
			// Invalid session, continue without user
			next.ServeHTTP(w, r)
			return
		}

		// Add user to context
		ctx := context.WithValue(r.Context(), UserContextKey, user)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// Required authentication - redirects to login if not authenticated
func (m *AuthMiddleware) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("RequireAuth middleware called for: %s", r.URL.Path)

		cookie, err := r.Cookie("session_token")
		if err != nil {
			log.Printf("RequireAuth: No session cookie found - %v", err)
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}

		// ✅ FIXED: Safe token logging
		tokenPreview := cookie.Value
		if len(tokenPreview) > 20 {
			tokenPreview = tokenPreview[:20] + "..."
		}
		log.Printf("RequireAuth: Cookie found, token: %s", tokenPreview)

		user, err := m.sessionService.GetUserByToken(cookie.Value)
		if err != nil {
			log.Printf("RequireAuth: Invalid session token - %v", err)
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}

		log.Printf("RequireAuth: User authenticated - %s (ID: %d)", user.Username, user.ID)

		// Add user to context
		ctx := context.WithValue(r.Context(), UserContextKey, user)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
