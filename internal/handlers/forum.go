package handlers

import (
	"database/sql"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"forum/internal/middleware"
	"forum/internal/models"
	"forum/internal/validation"
)

// Server timezone location
var serverLocation *time.Location

func init() {
	var err error
	// Load Kazakhstan timezone (Almaty/Astana)
	serverLocation, err = time.LoadLocation("Asia/Almaty")
	if err != nil {
		// Fallback to system local timezone
		serverLocation = time.Local
		log.Printf("Warning: Could not load Asia/Almaty timezone, using local time: %v", err)
	}
	log.Printf("Server timezone set to: %s", serverLocation)
}

// toLocalTime converts UTC time to server's local timezone
func toLocalTime(t time.Time) time.Time {
	return t.In(serverLocation)
}

type ForumHandler struct {
	db *sql.DB
}

func NewForumHandler(db *sql.DB) *ForumHandler {
	return &ForumHandler{
		db: db,
	}
}

// Helper function to render templates with layout
func (h *ForumHandler) renderTemplate(w http.ResponseWriter, name string, data interface{}) {
	tmpl, err := template.ParseFiles(
		"web/templates/layout.html",
		"web/templates/"+name+".html",
	)
	if err != nil {
		Render500(w, "Template parsing error: "+err.Error())
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	err = tmpl.ExecuteTemplate(w, "layout", data)
	if err != nil {
		Render500(w, "Template execution error: "+err.Error())
		return
	}
}

func (h *ForumHandler) getUserFromContext(r *http.Request) *models.User {
	if user := r.Context().Value(middleware.UserContextKey); user != nil {
		if u, ok := user.(*models.User); ok {
			return u
		}
	}
	return nil
}

func (h *ForumHandler) templateData(r *http.Request, title string) map[string]interface{} {
	return map[string]interface{}{
		"Title": title,
		"User":  h.getUserFromContext(r),
	}
}

func (h *ForumHandler) Home(w http.ResponseWriter, r *http.Request) {
	// ✅ NEW: Validate method
	if r.Method != http.MethodGet {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET requests.")
		return
	}

	categories, err := h.getCategories()
	if err != nil {
		RenderError(w, 500, "Internal Server Error", "Error loading categories. Please try again later.")
		log.Printf("Error loading categories: %v", err)
		return
	}

	user := h.getUserFromContext(r)
	var userID int
	if user != nil {
		userID = user.ID
	}

	filter := r.URL.Query().Get("filter")

	var recentPosts []models.Post
	var filterTitle string

	switch filter {
	case "my-posts":
		if user == nil {
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		recentPosts, err = h.getMyPosts(userID)
		filterTitle = "My Posts"
	case "liked-posts":
		if user == nil {
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		recentPosts, err = h.getLikedPosts(userID)
		filterTitle = "Liked Posts"
	default:
		recentPosts, err = h.getRecentPosts(userID)
		filterTitle = "Recent Posts"
	}

	if err != nil {
		RenderError(w, 500, "Internal Server Error", "Error loading posts. Please try again later.")
		log.Printf("Error loading posts: %v", err)
		return
	}

	// Convert all post times to local timezone
	for i := range recentPosts {
		recentPosts[i].CreatedAt = toLocalTime(recentPosts[i].CreatedAt)
	}

	data := h.templateData(r, "Forum Home")
	data["Categories"] = categories
	data["RecentPosts"] = recentPosts
	data["FilterTitle"] = filterTitle
	data["CurrentFilter"] = filter

	h.renderTemplate(w, "home", data)
}

func (h *ForumHandler) CategoryView(w http.ResponseWriter, r *http.Request) {
	// Validate method
	if r.Method != http.MethodGet {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET requests.")
		return
	}

	// Extract category slug from URL
	slug := strings.TrimPrefix(r.URL.Path, "/category/")
	if slug == "" || strings.Contains(slug, "/") {
		RenderError(w, 404, "Not Found", "Invalid category URL.")
		return
	}

	category, err := h.getCategoryBySlug(slug)
	if err != nil {
		if err == sql.ErrNoRows {
			RenderError(w, 404, "Category Not Found", "The category you're looking for doesn't exist.")
			return
		}
		log.Printf("Error loading category: %v", err)
		RenderError(w, 500, "Internal Server Error", "Error loading category. Please try again later.")
		return
	}

	user := h.getUserFromContext(r)
	var userID int
	if user != nil {
		userID = user.ID
	}

	// Get filter parameter (CONSISTENT with home page)
	filter := r.URL.Query().Get("filter")

	var posts []models.Post
	var filterTitle string

	// Apply filter based on user selection
	switch filter {
	case "my-posts":
		if user == nil {
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		posts, err = h.getMyPostsByCategory(userID, category.ID)
		filterTitle = "My Posts in " + category.Name
	case "liked-posts":
		if user == nil {
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}
		posts, err = h.getLikedPostsByCategory(userID, category.ID)
		filterTitle = "Liked Posts in " + category.Name
	default:
		posts, err = h.getPostsByCategory(category.ID, userID)
		filterTitle = "All Posts in " + category.Name
	}

	if err != nil {
		log.Printf("Error loading posts: %v", err)
		RenderError(w, 500, "Internal Server Error", "Error loading posts. Please try again later.")
		return
	}

	// Convert times to local timezone
	for i := range posts {
		posts[i].CreatedAt = toLocalTime(posts[i].CreatedAt)
	}

	data := h.templateData(r, category.Name)
	data["Category"] = category
	data["Posts"] = posts
	data["FilterTitle"] = filterTitle
	data["CurrentFilter"] = filter

	h.renderTemplate(w, "category", data)
}

// ============================================================================
// FIXED PostView Handler - Returns 400 for Invalid ID Format
// Replace in internal/handlers/forum.go (lines 3535-3580)
// ============================================================================

func (h *ForumHandler) PostView(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET requests.")
		return
	}

	idStr := strings.TrimPrefix(r.URL.Path, "/post/")

	// ✅ FIX 1: Return 400 for invalid format (not 404)
	id, err := strconv.Atoi(idStr)
	if err != nil {
		RenderError(w, 400, "Bad Request", "Invalid post ID format. Must be a number.")
		return
	}

	// ✅ FIX 2: Check for negative/zero IDs
	if id <= 0 {
		RenderError(w, 400, "Bad Request", "Post ID must be a positive number.")
		return
	}

	user := h.getUserFromContext(r)
	var userID int
	if user != nil {
		userID = user.ID
	}

	post, err := h.getPostByID(id, userID)
	if err != nil {
		// ✅ CORRECT: 404 for valid ID that doesn't exist
		RenderError(w, 404, "Not Found", "The post you're looking for doesn't exist.")
		return
	}

	h.incrementViewCount(id)

	comments, err := h.getCommentsByPostID(id, userID)
	if err != nil {
		RenderError(w, 500, "Internal Server Error", "Error loading comments. Please try again later.")
		return
	}

	// Convert post time to local timezone
	post.CreatedAt = toLocalTime(post.CreatedAt)

	// Convert all comment times to local timezone
	for i := range comments {
		comments[i].CreatedAt = toLocalTime(comments[i].CreatedAt)
	}

	data := h.templateData(r, post.Title)
	data["Post"] = post
	data["Comments"] = comments

	h.renderTemplate(w, "post", data)
}

// ============================================================================
// UPDATED CreatePost Handler with Explicit Category ID Validation
// Replace lines 3583-3695 in handlers/forum.go
// ============================================================================

func (h *ForumHandler) CreatePost(w http.ResponseWriter, r *http.Request) {
	user := h.getUserFromContext(r)
	if user == nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	if r.Method == http.MethodGet {
		categories, err := h.getCategories()
		if err != nil {
			RenderError(w, 500, "Internal Server Error", "Error loading categories. Please try again later.")
			return
		}

		data := h.templateData(r, "Create New Post")
		data["Categories"] = categories

		h.renderTemplate(w, "create_post", data)
		return
	}

	if r.Method == http.MethodPost {
		// ✅ STEP 1: Get raw input (NO TRIM YET!)
		title := r.FormValue("title")
		content := r.FormValue("content")

		// ✅ STEP 2: Clean dangerous Unicode only (preserves spaces for validation)
		title = validation.CleanText(title)
		content = validation.CleanText(content)

		err := r.ParseForm()
		if err != nil {
			RenderError(w, 400, "Bad Request", "Error parsing form data.")
			return
		}

		categoryIDStrs := r.Form["category_id[]"]

		// ✅ FIX: Validate category ID format EXPLICITLY before processing
		var categoryIDs []int
		for _, idStr := range categoryIDStrs {
			// Check for empty strings
			if strings.TrimSpace(idStr) == "" {
				categories, _ := h.getCategories()
				data := h.templateData(r, "Create New Post")
				data["Categories"] = categories
				data["Error"] = "Invalid category selection: empty category ID"
				data["Title"] = title
				data["Content"] = content

				h.renderTemplate(w, "create_post", data)
				return
			}

			// Try to parse as integer
			id, err := strconv.Atoi(idStr)
			if err != nil {
				categories, _ := h.getCategories()
				data := h.templateData(r, "Create New Post")
				data["Categories"] = categories
				data["Error"] = fmt.Sprintf("Invalid category ID format: '%s' must be a number", idStr)
				data["Title"] = title
				data["Content"] = content

				h.renderTemplate(w, "create_post", data)
				return
			}

			// Validate ID is positive
			if id <= 0 {
				categories, _ := h.getCategories()
				data := h.templateData(r, "Create New Post")
				data["Categories"] = categories
				data["Error"] = fmt.Sprintf("Invalid category ID: %d (must be positive)", id)
				data["Title"] = title
				data["Content"] = content

				h.renderTemplate(w, "create_post", data)
				return
			}

			categoryIDs = append(categoryIDs, id)
		}

		// Validate title
		if valid, errMsg := validation.ValidatePostTitle(title); !valid {
			categories, _ := h.getCategories()
			data := h.templateData(r, "Create New Post")
			data["Categories"] = categories
			data["Error"] = errMsg
			data["Title"] = title
			data["Content"] = content
			data["SelectedCategoryIDs"] = categoryIDs

			h.renderTemplate(w, "create_post", data)
			return
		}

		// Validate content
		if valid, errMsg := validation.ValidatePostContent(content); !valid {
			categories, _ := h.getCategories()
			data := h.templateData(r, "Create New Post")
			data["Categories"] = categories
			data["Error"] = errMsg
			data["Title"] = title
			data["Content"] = content
			data["SelectedCategoryIDs"] = categoryIDs

			h.renderTemplate(w, "create_post", data)
			return
		}

		// Validate categories
		if valid, errMsg := validation.ValidateCategories(categoryIDs); !valid {
			categories, _ := h.getCategories()
			data := h.templateData(r, "Create New Post")
			data["Categories"] = categories
			data["Error"] = errMsg
			data["Title"] = title
			data["Content"] = content
			data["SelectedCategoryIDs"] = categoryIDs

			h.renderTemplate(w, "create_post", data)
			return
		}

		// ✅ STEP 3: NOW TRIM - After validation passed
		// At this point, validation already rejected any leading/trailing spaces
		// This trim is just for safety (should be a no-op)
		title = strings.TrimSpace(title)
		content = strings.TrimSpace(content)

		postID, err := h.createPost(title, content, user.ID, categoryIDs)
		if err != nil {
			categories, _ := h.getCategories()
			data := h.templateData(r, "Create New Post")
			data["Categories"] = categories
			data["Error"] = "Error creating post: " + err.Error()
			data["Title"] = title
			data["Content"] = content
			data["SelectedCategoryIDs"] = categoryIDs

			h.renderTemplate(w, "create_post", data)
			return
		}

		http.Redirect(w, r, fmt.Sprintf("/post/%d", postID), http.StatusSeeOther)
		return
	}

	RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts GET and POST requests.")
}

// CreateComment handles POST /comment/{postID}
func (h *ForumHandler) CreateComment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		RenderError(w, 405, "Method Not Allowed", "This endpoint only accepts POST requests.")
		return
	}

	user := h.getUserFromContext(r)
	if user == nil {
		http.Redirect(w, r, "/login", http.StatusSeeOther)
		return
	}

	idStr := strings.TrimPrefix(r.URL.Path, "/comment/")

	// ✅ FIX 1: Add empty check before parsing
	if idStr == "" {
		RenderError(w, 400, "Bad Request", "Post ID is required.")
		return
	}

	postID, err := strconv.Atoi(idStr)
	if err != nil {
		// ✅ FIX 2: Change from 404 to 400 for invalid format
		RenderError(w, 400, "Bad Request", "Invalid post ID format. Must be a number.")
		return
	}

	// ✅ FIX 3: Add check for negative/zero IDs
	if postID <= 0 {
		RenderError(w, 400, "Bad Request", "Post ID must be a positive number.")
		return
	}

	// Check if post exists
	exists, err := h.postExists(postID)
	if err != nil {
		log.Printf("Error checking post existence: %v", err)
		RenderError(w, 500, "Internal Server Error", "Error processing comment. Please try again later.")
		return
	}
	if !exists {
		// ✅ CORRECT: 404 for missing resource (this is fine as-is)
		RenderError(w, 404, "Post Not Found", "The post you're trying to comment on doesn't exist.")
		return
	}

	// ✅ STEP 1: Get raw input (NO TRIM YET!)
	content := r.FormValue("content")

	// ✅ STEP 2: Clean dangerous Unicode only (preserves spaces for validation)
	content = validation.CleanText(content)

	// ✅ NEW: VALIDATE COMMENT CONTENT - Stay on page on error
	if valid, errMsg := validation.ValidateCommentContent(content); !valid {
		// Get post data to re-render the page
		post, err := h.getPostByID(postID, user.ID)
		if err != nil {
			log.Printf("Error loading post: %v", err)
			RenderError(w, 500, "Internal Server Error", "Error processing comment. Please try again later.")
			return
		}

		// Get existing comments
		comments, err := h.getCommentsByPostID(postID, user.ID)
		if err != nil {
			log.Printf("Error loading comments: %v", err)
			RenderError(w, 500, "Internal Server Error", "Error processing comment. Please try again later.")
			return
		}

		// Convert times to local timezone
		post.CreatedAt = toLocalTime(post.CreatedAt)
		for i := range comments {
			comments[i].CreatedAt = toLocalTime(comments[i].CreatedAt)
		}

		// Re-render post page with error message and preserve user's UNTRIMMED comment
		data := h.templateData(r, post.Title)
		data["Post"] = post
		data["Comments"] = comments
		data["CommentError"] = errMsg    // Error message to display
		data["CommentContent"] = content // Preserve user's input with spaces

		h.renderTemplate(w, "post", data)
		return
	}

	// ✅ STEP 3: NOW TRIM - After validation passed
	// At this point, validation already rejected any leading/trailing spaces
	content = strings.TrimSpace(content)

	err = h.insertComment(content, user.ID, postID)
	if err != nil {
		log.Printf("Error creating comment: %v", err)

		// ✅ NEW: On database error, also stay on page with error message
		post, postErr := h.getPostByID(postID, user.ID)
		if postErr != nil {
			// Fallback to error page if we can't load post
			RenderError(w, 500, "Internal Server Error", "Error creating comment. Please try again later.")
			return
		}

		comments, _ := h.getCommentsByPostID(postID, user.ID)

		post.CreatedAt = toLocalTime(post.CreatedAt)
		for i := range comments {
			comments[i].CreatedAt = toLocalTime(comments[i].CreatedAt)
		}

		data := h.templateData(r, post.Title)
		data["Post"] = post
		data["Comments"] = comments
		data["CommentError"] = "Error creating comment. Please try again later."
		data["CommentContent"] = content // Already trimmed at this point

		h.renderTemplate(w, "post", data)
		return
	}

	http.Redirect(w, r, fmt.Sprintf("/post/%d", postID), http.StatusSeeOther)
}

// Database helper methods
func (h *ForumHandler) getCategories() ([]models.Category, error) {
	query := `SELECT id, name, description, slug, created_at FROM categories ORDER BY name`
	rows, err := h.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var categories []models.Category
	for rows.Next() {
		var c models.Category
		err := rows.Scan(&c.ID, &c.Name, &c.Description, &c.Slug, &c.CreatedAt)
		if err != nil {
			return nil, err
		}
		categories = append(categories, c)
	}
	return categories, nil
}

// getRecentPosts retrieves recent posts with comment counts
func (h *ForumHandler) getRecentPosts(userID int) ([]models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count, 
		       p.created_at, u.username,
		       COUNT(DISTINCT c.id) as reply_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 1 THEN pl.id END) as like_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 0 THEN pl.id END) as dislike_count,
		       upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		LEFT JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ?
		GROUP BY p.id
		ORDER BY p.created_at DESC`

	rows, err := h.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []models.Post
	for rows.Next() {
		var p models.Post
		var userVote sql.NullBool
		err := rows.Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
			&p.ViewCount, &p.CreatedAt, &p.Username, &p.ReplyCount,
			&p.LikeCount, &p.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		p.HasVoted = userVote.Valid
		if userVote.Valid {
			p.IsLike = userVote.Bool
		}

		categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
		if err != nil {
			return nil, err
		}
		p.Categories = categories
		p.CategoryIDs = categoryIDs
		p.CategorySlugs = categorySlugs

		posts = append(posts, p)
	}
	return posts, nil
}

func (h *ForumHandler) getCategoryBySlug(slug string) (*models.Category, error) {
	query := `SELECT id, name, description, slug, created_at FROM categories WHERE slug = ?`
	var c models.Category
	err := h.db.QueryRow(query, slug).Scan(&c.ID, &c.Name, &c.Description, &c.Slug, &c.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// getPostsByCategory retrieves posts in a specific category
func (h *ForumHandler) getPostsByCategory(categoryID int, userID int) ([]models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count,
		       p.created_at, u.username,
		       COUNT(DISTINCT c.id) as reply_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 1 THEN pl.id END) as like_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 0 THEN pl.id END) as dislike_count,
		       upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		JOIN post_categories pc ON p.id = pc.post_id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		LEFT JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ?
		WHERE pc.category_id = ?
		GROUP BY p.id
		ORDER BY p.is_pinned DESC, p.created_at DESC`

	rows, err := h.db.Query(query, userID, categoryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []models.Post
	for rows.Next() {
		var p models.Post
		var userVote sql.NullBool
		err := rows.Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
			&p.ViewCount, &p.CreatedAt, &p.Username, &p.ReplyCount,
			&p.LikeCount, &p.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		p.HasVoted = userVote.Valid
		if userVote.Valid {
			p.IsLike = userVote.Bool
		}

		categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
		if err != nil {
			return nil, err
		}
		p.Categories = categories
		p.CategoryIDs = categoryIDs
		p.CategorySlugs = categorySlugs

		posts = append(posts, p)
	}
	return posts, nil
}

func (h *ForumHandler) getPostByID(id int, userID int) (*models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count,
			   p.created_at, u.username,
			   COALESCE(SUM(CASE WHEN pl.is_like = 1 THEN 1 ELSE 0 END), 0) as like_count,
			   COALESCE(SUM(CASE WHEN pl.is_like = 0 THEN 1 ELSE 0 END), 0) as dislike_count,
			   upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		LEFT JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ?
		WHERE p.id = ?
		GROUP BY p.id`

	var p models.Post
	var userVote sql.NullBool
	err := h.db.QueryRow(query, userID, id).Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
		&p.ViewCount, &p.CreatedAt, &p.Username,
		&p.LikeCount, &p.DislikeCount, &userVote)
	if err != nil {
		return nil, err
	}
	p.HasVoted = userVote.Valid
	if userVote.Valid {
		p.IsLike = userVote.Bool
	}

	categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
	if err != nil {
		return nil, err
	}
	p.Categories = categories
	p.CategoryIDs = categoryIDs
	p.CategorySlugs = categorySlugs

	return &p, nil
}

// getCommentsByPostID retrieves all comments for a given post
func (h *ForumHandler) getCommentsByPostID(postID int, userID int) ([]models.Comment, error) {
	query := `
		SELECT c.id, c.content, c.user_id, c.post_id, c.parent_id,
		       c.created_at, u.username,
		       COALESCE(SUM(CASE WHEN cl.is_like = 1 THEN 1 ELSE 0 END), 0) as like_count,
		       COALESCE(SUM(CASE WHEN cl.is_like = 0 THEN 1 ELSE 0 END), 0) as dislike_count,
		       ucl.is_like as user_vote
		FROM comments c
		JOIN users u ON c.user_id = u.id
		LEFT JOIN comment_likes cl ON c.id = cl.comment_id
		LEFT JOIN comment_likes ucl ON c.id = ucl.comment_id AND ucl.user_id = ?
		WHERE c.post_id = ?
		GROUP BY c.id
		ORDER BY c.created_at ASC`

	rows, err := h.db.Query(query, userID, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var comments []models.Comment
	for rows.Next() {
		var c models.Comment
		var userVote sql.NullBool
		err := rows.Scan(&c.ID, &c.Content, &c.UserID, &c.PostID, &c.ParentID,
			&c.CreatedAt, &c.Username, &c.LikeCount, &c.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		c.HasVoted = userVote.Valid
		if userVote.Valid {
			c.IsLike = userVote.Bool
		}
		comments = append(comments, c)
	}
	return comments, nil
}

func (h *ForumHandler) incrementViewCount(postID int) {
	query := `UPDATE posts SET view_count = view_count + 1 WHERE id = ?`
	h.db.Exec(query, postID)
}

func (h *ForumHandler) createPost(title, content string, userID int, categoryIDs []int) (int64, error) {
	tx, err := h.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	query := `
		INSERT INTO posts (title, content, user_id, created_at, updated_at)
		VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`

	result, err := tx.Exec(query, title, content, userID)
	if err != nil {
		return 0, err
	}

	postID, err := result.LastInsertId()
	if err != nil {
		return 0, err
	}

	if len(categoryIDs) > 0 {
		stmt, err := tx.Prepare("INSERT INTO post_categories (post_id, category_id) VALUES (?, ?)")
		if err != nil {
			return 0, err
		}
		defer stmt.Close()

		for _, categoryID := range categoryIDs {
			if _, err := stmt.Exec(postID, categoryID); err != nil {
				return 0, err
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}

	return postID, nil
}

// getMyPosts retrieves posts created by a specific user
func (h *ForumHandler) getMyPosts(userID int) ([]models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count, 
		       p.created_at, u.username,
		       COUNT(DISTINCT c.id) as reply_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 1 THEN pl.id END) as like_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 0 THEN pl.id END) as dislike_count,
		       upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		LEFT JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ?
		WHERE p.user_id = ?
		GROUP BY p.id
		ORDER BY p.created_at DESC`

	rows, err := h.db.Query(query, userID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []models.Post
	for rows.Next() {
		var p models.Post
		var userVote sql.NullBool
		err := rows.Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
			&p.ViewCount, &p.CreatedAt, &p.Username, &p.ReplyCount,
			&p.LikeCount, &p.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		p.HasVoted = userVote.Valid
		if userVote.Valid {
			p.IsLike = userVote.Bool
		}

		categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
		if err != nil {
			return nil, err
		}
		p.Categories = categories
		p.CategoryIDs = categoryIDs
		p.CategorySlugs = categorySlugs

		posts = append(posts, p)
	}
	return posts, nil
}

// getLikedPosts retrieves posts that a user has liked
func (h *ForumHandler) getLikedPosts(userID int) ([]models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count, 
		       p.created_at, u.username,
		       COUNT(DISTINCT c.id) as reply_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 1 THEN pl.id END) as like_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 0 THEN pl.id END) as dislike_count,
		       upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ? AND upl.is_like = 1
		GROUP BY p.id
		ORDER BY upl.created_at DESC`

	rows, err := h.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []models.Post
	for rows.Next() {
		var p models.Post
		var userVote sql.NullBool
		err := rows.Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
			&p.ViewCount, &p.CreatedAt, &p.Username, &p.ReplyCount,
			&p.LikeCount, &p.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		p.HasVoted = userVote.Valid
		if userVote.Valid {
			p.IsLike = userVote.Bool
		}

		categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
		if err != nil {
			return nil, err
		}
		p.Categories = categories
		p.CategoryIDs = categoryIDs
		p.CategorySlugs = categorySlugs

		posts = append(posts, p)
	}
	return posts, nil
}

func (h *ForumHandler) getCategoriesForPost(postID int) ([]string, []int, []string, error) {
	query := `
		SELECT c.id, c.name, c.slug
		FROM categories c
		JOIN post_categories pc ON c.id = pc.category_id
		WHERE pc.post_id = ?
		ORDER BY c.name`

	rows, err := h.db.Query(query, postID)
	if err != nil {
		return nil, nil, nil, err
	}
	defer rows.Close()

	var names []string
	var ids []int
	var slugs []string
	for rows.Next() {
		var id int
		var name string
		var slug string
		if err := rows.Scan(&id, &name, &slug); err != nil {
			return nil, nil, nil, err
		}
		ids = append(ids, id)
		names = append(names, name)
		slugs = append(slugs, slug)
	}
	return names, ids, slugs, nil
}

// postExists checks if a post with the given ID exists in the database
func (h *ForumHandler) postExists(postID int) (bool, error) {
	var exists int
	query := `SELECT 1 FROM posts WHERE id = ? LIMIT 1`
	err := h.db.QueryRow(query, postID).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// insertComment inserts a new comment into the database
func (h *ForumHandler) insertComment(content string, userID, postID int) error {
	query := `
		INSERT INTO comments (content, user_id, post_id, created_at, updated_at)
		VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`

	_, err := h.db.Exec(query, content, userID, postID)
	return err
}

// getMyPostsByCategory retrieves posts created by a specific user in a specific category
func (h *ForumHandler) getMyPostsByCategory(userID int, categoryID int) ([]models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count,
		       p.created_at, u.username,
		       COUNT(DISTINCT c.id) as reply_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 1 THEN pl.id END) as like_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 0 THEN pl.id END) as dislike_count,
		       upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		JOIN post_categories pc ON p.id = pc.post_id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		LEFT JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ?
		WHERE p.user_id = ? AND pc.category_id = ?
		GROUP BY p.id
		ORDER BY p.created_at DESC`

	rows, err := h.db.Query(query, userID, userID, categoryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []models.Post
	for rows.Next() {
		var p models.Post
		var userVote sql.NullBool
		err := rows.Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
			&p.ViewCount, &p.CreatedAt, &p.Username, &p.ReplyCount,
			&p.LikeCount, &p.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		p.HasVoted = userVote.Valid
		if userVote.Valid {
			p.IsLike = userVote.Bool
		}

		categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
		if err != nil {
			return nil, err
		}
		p.Categories = categories
		p.CategoryIDs = categoryIDs
		p.CategorySlugs = categorySlugs

		posts = append(posts, p)
	}
	return posts, nil
}

// getLikedPostsByCategory retrieves posts that a user has liked in a specific category
func (h *ForumHandler) getLikedPostsByCategory(userID int, categoryID int) ([]models.Post, error) {
	query := `
		SELECT p.id, p.title, p.content, p.user_id, p.view_count, 
		       p.created_at, u.username,
		       COUNT(DISTINCT c.id) as reply_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 1 THEN pl.id END) as like_count,
		       COUNT(DISTINCT CASE WHEN pl.is_like = 0 THEN pl.id END) as dislike_count,
		       upl.is_like as user_vote
		FROM posts p
		JOIN users u ON p.user_id = u.id
		JOIN post_categories pc ON p.id = pc.post_id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_likes pl ON p.id = pl.post_id
		JOIN post_likes upl ON p.id = upl.post_id AND upl.user_id = ? AND upl.is_like = 1
		WHERE pc.category_id = ?
		GROUP BY p.id
		ORDER BY upl.created_at DESC`

	rows, err := h.db.Query(query, userID, categoryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []models.Post
	for rows.Next() {
		var p models.Post
		var userVote sql.NullBool
		err := rows.Scan(&p.ID, &p.Title, &p.Content, &p.UserID,
			&p.ViewCount, &p.CreatedAt, &p.Username, &p.ReplyCount,
			&p.LikeCount, &p.DislikeCount, &userVote)
		if err != nil {
			return nil, err
		}
		p.HasVoted = userVote.Valid
		if userVote.Valid {
			p.IsLike = userVote.Bool
		}

		categories, categoryIDs, categorySlugs, err := h.getCategoriesForPost(p.ID)
		if err != nil {
			return nil, err
		}
		p.Categories = categories
		p.CategoryIDs = categoryIDs
		p.CategorySlugs = categorySlugs

		posts = append(posts, p)
	}
	return posts, nil
}
