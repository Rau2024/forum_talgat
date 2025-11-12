package handlers

import (
	"log"
	"net/http"
	"strconv"
	"strings"

	"forum/internal/middleware"
	"forum/internal/models"
	"forum/internal/services"
)

type LikesHandler struct {
	likesService *services.LikesService
}

func NewLikesHandler(likesService *services.LikesService) *LikesHandler {
	return &LikesHandler{
		likesService: likesService,
	}
}

func (h *LikesHandler) getUserFromContext(r *http.Request) *models.User {
	if user := r.Context().Value(middleware.UserContextKey); user != nil {
		if u, ok := user.(*models.User); ok {
			return u
		}
	}
	return nil
}

// LikePost handles POST /post/{id}/like
func (h *LikesHandler) LikePost(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts POST requests.")
		return
	}

	user := h.getUserFromContext(r)
	if user == nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	// Extract post ID from URL: /post/123/like
	path := strings.TrimPrefix(r.URL.Path, "/post/")
	parts := strings.Split(path, "/")
	if len(parts) < 2 {
		RenderError(w, 404, "Not Found", "Invalid post URL.")
		return
	}

	postID, err := strconv.Atoi(parts[0])
	if err != nil {
		RenderError(w, 404, "Not Found", "Invalid post ID.")
		return
	}

	err = h.likesService.LikePost(user.ID, postID)
	if err != nil {
		log.Printf("Error liking post: %v", err)

		if strings.Contains(err.Error(), "post not found") {
			RenderError(w, 404, "Post Not Found", "The post you're trying to like doesn't exist.")
			return
		}

		RenderError(w, 500, "Internal Server Error", "Error processing like. Please try again.")
		return
	}

	// Redirect back to the post
	http.Redirect(w, r, "/post/"+parts[0], http.StatusSeeOther)
}

// DislikePost handles POST /post/{id}/dislike
func (h *LikesHandler) DislikePost(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts POST requests.")
		return
	}

	user := h.getUserFromContext(r)
	if user == nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/post/")
	parts := strings.Split(path, "/")
	if len(parts) < 2 {
		RenderError(w, 404, "Not Found", "Invalid post URL.")
		return
	}

	postID, err := strconv.Atoi(parts[0])
	if err != nil {
		RenderError(w, 404, "Not Found", "Invalid post ID.")
		return
	}

	err = h.likesService.DislikePost(user.ID, postID)
	if err != nil {
		log.Printf("Error disliking post: %v", err)

		if strings.Contains(err.Error(), "post not found") {
			RenderError(w, 404, "Post Not Found", "The post you're trying to dislike doesn't exist.")
			return
		}

		RenderError(w, 500, "Internal Server Error", "Error processing dislike. Please try again.")
		return
	}

	http.Redirect(w, r, "/post/"+parts[0], http.StatusSeeOther)
}

// LikeComment handles POST /comment/{id}/like
func (h *LikesHandler) LikeComment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts POST requests.")
		return
	}

	user := h.getUserFromContext(r)
	if user == nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/comment/")
	parts := strings.Split(path, "/")

	// ✅ FIX 1: Better error message for malformed URL
	if len(parts) < 2 {
		RenderError(w, 400, "Bad Request", "Invalid comment URL format. Expected: /comment/{id}/like")
		return
	}

	// ✅ FIX 2: Check for empty comment ID
	if parts[0] == "" {
		RenderError(w, 400, "Bad Request", "Comment ID is required.")
		return
	}

	commentID, err := strconv.Atoi(parts[0])
	if err != nil {
		// ✅ FIX 3: Change from 404 to 400 for invalid format
		RenderError(w, 400, "Bad Request", "Invalid comment ID format. Must be a number.")
		return
	}

	// ✅ FIX 4: Check for negative/zero IDs
	if commentID <= 0 {
		RenderError(w, 400, "Bad Request", "Comment ID must be a positive number.")
		return
	}

	// Get the post ID to redirect back
	postID := r.FormValue("post_id")
	if postID == "" {
		RenderError(w, 400, "Bad Request", "Missing post ID.")
		return
	}

	// ✅ FIX 5: Validate post ID format
	postIDInt, err := strconv.Atoi(postID)
	if err != nil {
		RenderError(w, 400, "Bad Request", "Invalid post ID format. Must be a number.")
		return
	}

	if postIDInt <= 0 {
		RenderError(w, 400, "Bad Request", "Post ID must be a positive number.")
		return
	}

	err = h.likesService.LikeComment(user.ID, commentID)
	if err != nil {
		log.Printf("Error liking comment: %v", err)

		if strings.Contains(err.Error(), "comment not found") {
			// ✅ CORRECT: 404 for missing resource (this is fine as-is)
			RenderError(w, 404, "Comment Not Found", "The comment you're trying to like doesn't exist.")
			return
		}

		RenderError(w, 500, "Internal Server Error", "Error processing like. Please try again.")
		return
	}

	http.Redirect(w, r, "/post/"+postID, http.StatusSeeOther)
}

// DislikeComment handles POST /comment/{id}/dislike
func (h *LikesHandler) DislikeComment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts POST requests.")
		return
	}

	user := h.getUserFromContext(r)
	if user == nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/comment/")
	parts := strings.Split(path, "/")

	// ✅ FIX 1: Better error message for malformed URL
	if len(parts) < 2 {
		RenderError(w, 400, "Bad Request", "Invalid comment URL format. Expected: /comment/{id}/dislike")
		return
	}

	// ✅ FIX 2: Check for empty comment ID
	if parts[0] == "" {
		RenderError(w, 400, "Bad Request", "Comment ID is required.")
		return
	}

	commentID, err := strconv.Atoi(parts[0])
	if err != nil {
		// ✅ FIX 3: Change from 404 to 400 for invalid format
		RenderError(w, 400, "Bad Request", "Invalid comment ID format. Must be a number.")
		return
	}

	// ✅ FIX 4: Check for negative/zero IDs
	if commentID <= 0 {
		RenderError(w, 400, "Bad Request", "Comment ID must be a positive number.")
		return
	}

	postID := r.FormValue("post_id")
	if postID == "" {
		RenderError(w, 400, "Bad Request", "Missing post ID.")
		return
	}

	// ✅ FIX 5: Validate post ID format
	postIDInt, err := strconv.Atoi(postID)
	if err != nil {
		RenderError(w, 400, "Bad Request", "Invalid post ID format. Must be a number.")
		return
	}

	if postIDInt <= 0 {
		RenderError(w, 400, "Bad Request", "Post ID must be a positive number.")
		return
	}

	err = h.likesService.DislikeComment(user.ID, commentID)
	if err != nil {
		log.Printf("Error disliking comment: %v", err)

		if strings.Contains(err.Error(), "comment not found") {
			// ✅ CORRECT: 404 for missing resource (this is fine as-is)
			RenderError(w, 404, "Comment Not Found", "The comment you're trying to dislike doesn't exist.")
			return
		}

		RenderError(w, 500, "Internal Server Error", "Error processing dislike. Please try again.")
		return
	}

	http.Redirect(w, r, "/post/"+postID, http.StatusSeeOther)
}
