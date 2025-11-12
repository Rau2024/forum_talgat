package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"forum/internal/config"
	"forum/internal/database"
	"forum/internal/handlers"
	"forum/internal/middleware"
	"forum/internal/services"
)

// findProjectRoot walks up the directory tree to find the project root
func findProjectRoot() (string, error) {
	// Start from current working directory
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	// Walk up the directory tree
	for {
		// Check if go.mod exists in current directory
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}

		// Get parent directory
		parent := filepath.Dir(dir)

		// If we've reached the root without finding go.mod
		if parent == dir {
			return "", fmt.Errorf("could not find project root (go.mod not found)")
		}

		dir = parent
	}
}

// staticFileServer creates a secure static file server WITHOUT directory listing
func staticFileServer() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Security check 1: Only allow GET and HEAD methods
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			handlers.RenderError(w, 405, "Method Not Allowed",
				"Static files can only be accessed with GET or HEAD requests.")
			return
		}

		// Security check 2: Prevent directory traversal attacks
		path := strings.TrimPrefix(r.URL.Path, "/static/")

		if strings.Contains(path, "..") {
			handlers.RenderError(w, 400, "Bad Request",
				"Invalid file path.")
			log.Printf("Security: Directory traversal attempt blocked: %s", r.URL.Path)
			return
		}

		// ✅ NEW: Block directory requests (prevent directory listing)
		if path == "" || strings.HasSuffix(path, "/") {
			handlers.RenderError(w, 403, "Forbidden",
				"Directory listing is not allowed.")
			log.Printf("Security: Directory listing attempt blocked: %s", r.URL.Path)
			return
		}

		// Security check 3: Only allow specific file extensions
		allowedExtensions := []string{".css", ".js", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".woff", ".woff2", ".ttf"}
		ext := filepath.Ext(path)
		allowed := false
		for _, allowedExt := range allowedExtensions {
			if strings.EqualFold(ext, allowedExt) {
				allowed = true
				break
			}
		}

		if !allowed && ext != "" {
			handlers.RenderError(w, 403, "Forbidden",
				"This file type is not allowed.")
			log.Printf("Security: Blocked file type: %s", ext)
			return
		}

		// ✅ NEW: Check if file exists and is not a directory
		fullPath := filepath.Join("web/static", path)
		fileInfo, err := os.Stat(fullPath)
		if err != nil {
			handlers.RenderError(w, 404, "Not Found",
				"The requested file was not found.")
			return
		}

		if fileInfo.IsDir() {
			handlers.RenderError(w, 403, "Forbidden",
				"Directory listing is not allowed.")
			log.Printf("Security: Directory access blocked: %s", r.URL.Path)
			return
		}

		// Security check 4: Set security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'none'; style-src 'self'; img-src 'self' data:; font-src 'self';")

		// Set cache headers for better performance
		if ext == ".css" || ext == ".js" {
			w.Header().Set("Cache-Control", "public, max-age=86400") // 24 hours
		} else if ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".gif" || ext == ".svg" || ext == ".ico" {
			w.Header().Set("Cache-Control", "public, max-age=604800") // 7 days
		}

		// Log the request
		log.Printf("Static file request: %s", r.URL.Path)

		// Serve the file directly (not using http.FileServer)
		http.ServeFile(w, r, fullPath)
	})
}

func main() {
	// Find project root
	projectRoot, err := findProjectRoot()
	if err != nil {
		log.Fatal("Error finding project root: ", err)
	}

	log.Printf("Project root: %s", projectRoot)

	// Change working directory to project root
	// This ensures all relative paths work correctly
	if err := os.Chdir(projectRoot); err != nil {
		log.Fatal("Failed to change to project root:", err)
	}

	cfg := config.Load()

	// Initialize database (now relative paths work from project root)
	db, err := database.InitDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer db.Close()

	if err := database.RunMigrations(db); err != nil {
		log.Fatal("Failed to run migrations:", err)
	}

	// Initialize services
	userService := services.NewUserService(db)
	sessionService := services.NewSessionService(db)
	likesService := services.NewLikesService(db)

	// Initialize handlers
	forumHandler := handlers.NewForumHandler(db)
	authHandler := handlers.NewAuthHandler(userService, sessionService)
	likesHandler := handlers.NewLikesHandler(likesService)

	// Initialize middleware
	authMiddleware := middleware.NewAuthMiddleware(sessionService)

	// Setup routes
	mux := http.NewServeMux()

	// ✅ NEW: Static file server with security checks
	mux.Handle("/static/", http.StripPrefix("/static/", staticFileServer()))

	// ✅ NEW: Favicon handling (stops 404 errors)
	mux.HandleFunc("/favicon.ico", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			handlers.RenderError(w, 405, "Method Not Allowed", "Only GET and HEAD methods allowed")
			return
		}
		http.ServeFile(w, r, "web/static/favicon.ico")
	})

	mux.HandleFunc("/apple-touch-icon.png", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			handlers.RenderError(w, 405, "Method Not Allowed", "Only GET and HEAD methods allowed")
			return
		}
		http.ServeFile(w, r, "web/static/apple-touch-icon.png")
	})

	mux.HandleFunc("/apple-touch-icon-precomposed.png", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			handlers.RenderError(w, 405, "Method Not Allowed", "Only GET and HEAD methods allowed")
			return
		}
		http.ServeFile(w, r, "web/static/apple-touch-icon-precomposed.png")
	})

	// Public routes with optional auth (shows user info if logged in)
	mux.HandleFunc("/category/", wrapOptionalAuth(authMiddleware, forumHandler.CategoryView))
	mux.HandleFunc("/post/", handlePostRoutes(authMiddleware, forumHandler, likesHandler))

	// Auth routes
	mux.HandleFunc("/register", authHandler.Register)
	mux.HandleFunc("/login", authHandler.Login)
	mux.HandleFunc("/logout", authHandler.Logout)

	// Protected routes (require login)
	mux.Handle("/post/create", authMiddleware.RequireAuth(http.HandlerFunc(forumHandler.CreatePost)))
	mux.HandleFunc("/comment/", handleCommentRoutes(authMiddleware, forumHandler, likesHandler))

	// Home and 404 handler
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// If path is exactly "/", show home
		if r.URL.Path == "/" {
			wrapOptionalAuth(authMiddleware, forumHandler.Home)(w, r)
			return
		}

		// Everything else is 404
		handlers.RenderError(w, 404, "Page Not Found",
			"The page you're looking for doesn't exist.")
	})

	// Logging middleware
	handler := loggingMiddleware(mux)

	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Printf("Starting full-featured forum on :%s", cfg.Port)
	log.Printf("Visit: http://localhost:%s", cfg.Port)
	log.Fatal(server.ListenAndServe())
}

// Helper to wrap handlers with optional auth
func wrapOptionalAuth(authMiddleware *middleware.AuthMiddleware, handler func(http.ResponseWriter, *http.Request)) http.HandlerFunc {
	return authMiddleware.OptionalAuth(http.HandlerFunc(handler)).ServeHTTP
}

// Handle post routes - differentiates between viewing posts and like/dislike actions
func handlePostRoutes(authMiddleware *middleware.AuthMiddleware, forumHandler *handlers.ForumHandler, likesHandler *handlers.LikesHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		// Check if it's a like/dislike action
		if len(path) > 6 && path[len(path)-5:] == "/like" {
			// Protected route - requires auth
			authMiddleware.RequireAuth(http.HandlerFunc(likesHandler.LikePost)).ServeHTTP(w, r)
			return
		}
		if len(path) > 9 && path[len(path)-8:] == "/dislike" {
			// Protected route - requires auth
			authMiddleware.RequireAuth(http.HandlerFunc(likesHandler.DislikePost)).ServeHTTP(w, r)
			return
		}

		// Otherwise it's a post view - optional auth
		authMiddleware.OptionalAuth(http.HandlerFunc(forumHandler.PostView)).ServeHTTP(w, r)
	}
}

// handleCommentRoutes handles comment creation and like/dislike actions
func handleCommentRoutes(authMiddleware *middleware.AuthMiddleware, forumHandler *handlers.ForumHandler, likesHandler *handlers.LikesHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		// ✅ CRITICAL SECURITY FIX: Block double slashes BEFORE any routing
		// This prevents Go's ServeMux from issuing 301 redirects
		// Without this, /comment//like gets redirected and causes 405 errors
		if strings.Contains(path, "//") {
			handlers.RenderError(w, 400, "Bad Request", "Invalid URL format: double slashes not allowed")
			log.Printf("Security: Double slash detected and blocked: %s", path)
			return
		}

		// ✅ SECURITY FIX: Validate that comment ID exists
		// Extract the part after /comment/
		pathAfterComment := strings.TrimPrefix(path, "/comment/")

		// If path is /comment/ or starts immediately with action (/comment/like), reject it
		if pathAfterComment == "" ||
			pathAfterComment == "like" ||
			pathAfterComment == "dislike" ||
			strings.HasPrefix(pathAfterComment, "like/") ||
			strings.HasPrefix(pathAfterComment, "dislike/") {
			handlers.RenderError(w, 400, "Bad Request", "Comment ID is required")
			log.Printf("Security: Missing comment ID in route: %s", path)
			return
		}

		// Check if it's a like/dislike action
		if len(path) > 6 && path[len(path)-5:] == "/like" {
			// Protected route - requires auth
			authMiddleware.RequireAuth(http.HandlerFunc(likesHandler.LikeComment)).ServeHTTP(w, r)
			return
		}
		if len(path) > 9 && path[len(path)-8:] == "/dislike" {
			// Protected route - requires auth
			authMiddleware.RequireAuth(http.HandlerFunc(likesHandler.DislikeComment)).ServeHTTP(w, r)
			return
		}

		// Otherwise it's a comment creation - requires auth
		authMiddleware.RequireAuth(http.HandlerFunc(forumHandler.CreateComment)).ServeHTTP(w, r)
	}
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		log.Printf("Request: %s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
		log.Printf("Response: %s %s %v", r.Method, r.URL.Path, time.Since(start))
	})
}
