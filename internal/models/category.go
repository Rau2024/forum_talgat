package models

import (
	"database/sql"
	"time"
)

type Category struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	Slug        string    `json:"slug" db:"slug"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

type Comment struct {
	ID        int       `json:"id" db:"id"`
	Content   string    `json:"content" db:"content"`
	UserID    int       `json:"user_id" db:"user_id"`
	PostID    int       `json:"post_id" db:"post_id"`
	ParentID  *int      `json:"parent_id" db:"parent_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`

	// Joined fields
	Username     string `json:"username" db:"username"`
	LikeCount    int    `json:"like_count" db:"like_count"`
	DislikeCount int    `json:"dislike_count" db:"dislike_count"`

	// Current user's vote - exported for templates
	UserVoteValue sql.NullBool `json:"-"` // Internal field
	HasVoted      bool         `json:"has_voted"`
	IsLike        bool         `json:"is_like"`
}
