package handlers

import (
	"html/template"
	"log"
	"net/http"
	"strings"
	"time"

	"forum/internal/services"
	"forum/internal/validation"
)

type AuthHandler struct {
	userService    *services.UserService
	sessionService *services.SessionService
}

func NewAuthHandler(userService *services.UserService, sessionService *services.SessionService) *AuthHandler {
	return &AuthHandler{
		userService:    userService,
		sessionService: sessionService,
	}
}

// renderAuthTemplate renders standalone auth templates (no layout)
// Following the ForumHandler pattern for consistency
func (h *AuthHandler) renderAuthTemplate(w http.ResponseWriter, name string, data interface{}) {
	tmpl, err := template.ParseFiles("web/templates/" + name + ".html")
	if err != nil {
		Render500(w, "Template parsing error: "+err.Error())
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	err = tmpl.Execute(w, data)
	if err != nil {
		Render500(w, "Template execution error: "+err.Error())
		return
	}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		data := map[string]interface{}{
			"Title": "Register",
		}
		h.renderAuthTemplate(w, "register", data)
		return
	}

	if r.Method == http.MethodPost {
		// ✅ STEP 1: Get raw input (NO TRIM YET!)
		username := r.FormValue("username")
		email := r.FormValue("email")
		password := r.FormValue("password")
		confirmPassword := r.FormValue("confirm_password")

		// ✅ STEP 2: Clean dangerous Unicode only (preserves spaces for validation)
		username = validation.CleanText(username)
		// Email and password don't need CleanText

		// ✅ STEP 3: Validate username (will check for spaces and reject them)
		if valid, errMsg := validation.ValidateUsername(username); !valid {
			data := map[string]interface{}{
				"Title":    "Register",
				"Error":    errMsg,
				"Username": username, // Preserve input for user to see/fix
				"Email":    email,
			}
			h.renderAuthTemplate(w, "register", data)
			return
		}

		// ✅ STEP 4: Validate email (will check for spaces and reject them)
		if valid, errMsg := validation.ValidateEmail(email); !valid {
			data := map[string]interface{}{
				"Title":    "Register",
				"Error":    errMsg,
				"Username": username,
				"Email":    email,
			}
			h.renderAuthTemplate(w, "register", data)
			return
		}

		// ✅ STEP 5: Validate password (already rejects spaces)
		if valid, errMsg := validation.ValidatePassword(password); !valid {
			data := map[string]interface{}{
				"Title":    "Register",
				"Error":    errMsg,
				"Username": username,
				"Email":    email,
			}
			h.renderAuthTemplate(w, "register", data)
			return
		}

		// Check password match
		if password != confirmPassword {
			data := map[string]interface{}{
				"Title":    "Register",
				"Error":    "Passwords do not match",
				"Username": username,
				"Email":    email,
			}
			h.renderAuthTemplate(w, "register", data)
			return
		}

		// ✅ STEP 6: NOW TRIM - After all validation passed
		// At this point, validation already rejected any spaces
		// This trim is just for safety (should be a no-op)
		username = strings.TrimSpace(username)
		email = strings.TrimSpace(email)
		// Password: No trim (already validated no spaces, preserve exact chars)

		_, err := h.userService.CreateUser(username, email, password)
		if err != nil {
			data := map[string]interface{}{
				"Title":    "Register",
				"Error":    err.Error(),
				"Username": username,
				"Email":    email,
			}
			h.renderAuthTemplate(w, "register", data)
			return
		}

		http.Redirect(w, r, "/login?registered=1", http.StatusSeeOther)
		return
	}
	RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET and POST requests")
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	log.Printf("Login handler called - Method: %s", r.Method)

	if r.Method == http.MethodGet {
		data := map[string]interface{}{
			"Title": "Login",
		}
		if r.URL.Query().Get("registered") == "1" {
			data["Success"] = "Registration successful! Please log in."
		}
		h.renderAuthTemplate(w, "login", data)
		return
	}

	if r.Method == http.MethodPost {
		username := r.FormValue("username")
		password := r.FormValue("password")

		log.Printf("Login attempt - username: %s, password length: %d", username, len(password))

		user, err := h.userService.AuthenticateUser(username, password)
		if err != nil {
			log.Printf("Authentication failed: %v", err)
			data := map[string]interface{}{
				"Title": "Login",
				"Error": err.Error(),
			}
			h.renderAuthTemplate(w, "login", data)
			return
		}

		log.Printf("Authentication successful for user: %s (ID: %d)", user.Username, user.ID)

		// Create session
		token, err := h.sessionService.CreateSession(user.ID)
		if err != nil {
			log.Printf("Session creation failed: %v", err)
			RenderError(w, 500, "Internal Server Error", "Error creating session. Please try again.")
			return
		}

		log.Printf("Session created with token: %s", token[:20]+"...")

		// Set session cookie
		cookie := &http.Cookie{
			Name:     "session_token",
			Value:    token,
			Path:     "/",
			Expires:  time.Now().Add(24 * time.Hour),
			HttpOnly: true,
			SameSite: http.SameSiteLaxMode,
		}
		http.SetCookie(w, cookie)

		log.Printf("Cookie set, redirecting to /")

		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET and POST requests.")
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	// Validate method (allow both GET and POST for flexibility)
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET and POST requests.")
		return
	}

	cookie, err := r.Cookie("session_token")
	if err == nil {
		// Delete session from database
		h.sessionService.DeleteSession(cookie.Value)
	}

	// Clear session cookie
	cookie = &http.Cookie{
		Name:     "session_token",
		Value:    "",
		Path:     "/",
		Expires:  time.Unix(0, 0),
		HttpOnly: true,
	}
	http.SetCookie(w, cookie)

	http.Redirect(w, r, "/", http.StatusSeeOther)
}
