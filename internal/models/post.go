package models

import (
	"database/sql"
	"time"
)

type Post struct {
	ID        int       `json:"id" db:"id"`
	Title     string    `json:"title" db:"title"`
	Content   string    `json:"content" db:"content"`
	UserID    int       `json:"user_id" db:"user_id"`
	IsPinned  bool      `json:"is_pinned" db:"is_pinned"`
	IsLocked  bool      `json:"is_locked" db:"is_locked"`
	ViewCount int       `json:"view_count" db:"view_count"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`

	// Joined fields
	Username      string   `json:"username" db:"username"`
	Categories    []string `json:"categories"`     // Category names (for display)
	CategoryIDs   []int    `json:"category_ids"`   // Category IDs (for processing)
	CategorySlugs []string `json:"category_slugs"` // Category slugs (for URLs) - ADD THIS
	ReplyCount    int      `json:"reply_count" db:"reply_count"`
	LikeCount     int      `json:"like_count" db:"like_count"`
	DislikeCount  int      `json:"dislike_count" db:"dislike_count"`

	// Current user's vote - exported for templates
	UserVoteValue sql.NullBool `json:"-"` // Internal field
	HasVoted      bool         `json:"has_voted"`
	IsLike        bool         `json:"is_like"`
}
