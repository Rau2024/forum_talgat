package services

import (
	"database/sql"
	"fmt"
)

type LikesService struct {
	db *sql.DB
}

func NewLikesService(db *sql.DB) *LikesService {
	return &LikesService{db: db}
}

// postExists checks if a post with the given ID exists
func (s *LikesService) postExists(postID int) (bool, error) {
	var exists int
	query := `SELECT 1 FROM posts WHERE id = ? LIMIT 1`
	err := s.db.QueryRow(query, postID).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// commentExists checks if a comment with the given ID exists
func (s *LikesService) commentExists(commentID int) (bool, error) {
	var exists int
	query := `SELECT 1 FROM comments WHERE id = ? LIMIT 1`
	err := s.db.QueryRow(query, commentID).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// LikePost toggles or sets a like on a post
func (s *LikesService) LikePost(userID, postID int) error {
	// Check if post exists FIRST
	exists, err := s.postExists(postID)
	if err != nil {
		return fmt.Errorf("database error: %w", err)
	}
	if !exists {
		return fmt.Errorf("post not found")
	}

	var currentVote sql.NullBool
	checkQuery := `SELECT is_like FROM post_likes WHERE user_id = ? AND post_id = ?`
	err = s.db.QueryRow(checkQuery, userID, postID).Scan(&currentVote)

	if err == sql.ErrNoRows {
		// No existing vote - insert new like
		insertQuery := `INSERT INTO post_likes (user_id, post_id, is_like) VALUES (?, ?, TRUE)`
		_, err = s.db.Exec(insertQuery, userID, postID)
		return err
	}

	if err != nil {
		return err
	}

	// If already liked, remove the vote (toggle off)
	if currentVote.Valid && currentVote.Bool {
		deleteQuery := `DELETE FROM post_likes WHERE user_id = ? AND post_id = ?`
		_, err = s.db.Exec(deleteQuery, userID, postID)
		return err
	}

	// If disliked, change to like
	updateQuery := `UPDATE post_likes SET is_like = TRUE WHERE user_id = ? AND post_id = ?`
	_, err = s.db.Exec(updateQuery, userID, postID)
	return err
}

// DislikePost toggles or sets a dislike on a post
func (s *LikesService) DislikePost(userID, postID int) error {
	// Check if post exists FIRST
	exists, err := s.postExists(postID)
	if err != nil {
		return fmt.Errorf("database error: %w", err)
	}
	if !exists {
		return fmt.Errorf("post not found")
	}

	var currentVote sql.NullBool
	checkQuery := `SELECT is_like FROM post_likes WHERE user_id = ? AND post_id = ?`
	err = s.db.QueryRow(checkQuery, userID, postID).Scan(&currentVote)

	if err == sql.ErrNoRows {
		// No existing vote - insert new dislike
		insertQuery := `INSERT INTO post_likes (user_id, post_id, is_like) VALUES (?, ?, FALSE)`
		_, err = s.db.Exec(insertQuery, userID, postID)
		return err
	}

	if err != nil {
		return err
	}

	// If already disliked, remove the vote (toggle off)
	if currentVote.Valid && !currentVote.Bool {
		deleteQuery := `DELETE FROM post_likes WHERE user_id = ? AND post_id = ?`
		_, err = s.db.Exec(deleteQuery, userID, postID)
		return err
	}

	// If liked, change to dislike
	updateQuery := `UPDATE post_likes SET is_like = FALSE WHERE user_id = ? AND post_id = ?`
	_, err = s.db.Exec(updateQuery, userID, postID)
	return err
}

// RemovePostVote removes a user's vote from a post
func (s *LikesService) RemovePostVote(userID, postID int) error {
	query := `DELETE FROM post_likes WHERE user_id = ? AND post_id = ?`
	_, err := s.db.Exec(query, userID, postID)
	return err
}

// LikeComment toggles or sets a like on a comment
func (s *LikesService) LikeComment(userID, commentID int) error {
	// Check if comment exists FIRST
	exists, err := s.commentExists(commentID)
	if err != nil {
		return fmt.Errorf("database error: %w", err)
	}
	if !exists {
		return fmt.Errorf("comment not found")
	}

	var currentVote sql.NullBool
	checkQuery := `SELECT is_like FROM comment_likes WHERE user_id = ? AND comment_id = ?`
	err = s.db.QueryRow(checkQuery, userID, commentID).Scan(&currentVote)

	if err == sql.ErrNoRows {
		insertQuery := `INSERT INTO comment_likes (user_id, comment_id, is_like) VALUES (?, ?, TRUE)`
		_, err = s.db.Exec(insertQuery, userID, commentID)
		return err
	}

	if err != nil {
		return err
	}

	// If already liked, remove the vote (toggle off)
	if currentVote.Valid && currentVote.Bool {
		deleteQuery := `DELETE FROM comment_likes WHERE user_id = ? AND comment_id = ?`
		_, err = s.db.Exec(deleteQuery, userID, commentID)
		return err
	}

	// If disliked, change to like
	updateQuery := `UPDATE comment_likes SET is_like = TRUE WHERE user_id = ? AND comment_id = ?`
	_, err = s.db.Exec(updateQuery, userID, commentID)
	return err
}

// DislikeComment toggles or sets a dislike on a comment
func (s *LikesService) DislikeComment(userID, commentID int) error {
	// Check if comment exists FIRST
	exists, err := s.commentExists(commentID)
	if err != nil {
		return fmt.Errorf("database error: %w", err)
	}
	if !exists {
		return fmt.Errorf("comment not found")
	}

	var currentVote sql.NullBool
	checkQuery := `SELECT is_like FROM comment_likes WHERE user_id = ? AND comment_id = ?`
	err = s.db.QueryRow(checkQuery, userID, commentID).Scan(&currentVote)

	if err == sql.ErrNoRows {
		insertQuery := `INSERT INTO comment_likes (user_id, comment_id, is_like) VALUES (?, ?, FALSE)`
		_, err = s.db.Exec(insertQuery, userID, commentID)
		return err
	}

	if err != nil {
		return err
	}

	// If already disliked, remove the vote (toggle off)
	if currentVote.Valid && !currentVote.Bool {
		deleteQuery := `DELETE FROM comment_likes WHERE user_id = ? AND comment_id = ?`
		_, err = s.db.Exec(deleteQuery, userID, commentID)
		return err
	}

	// If liked, change to dislike
	updateQuery := `UPDATE comment_likes SET is_like = FALSE WHERE user_id = ? AND comment_id = ?`
	_, err = s.db.Exec(updateQuery, userID, commentID)
	return err
}

// RemoveCommentVote removes a user's vote from a comment
func (s *LikesService) RemoveCommentVote(userID, commentID int) error {
	query := `DELETE FROM comment_likes WHERE user_id = ? AND comment_id = ?`
	_, err := s.db.Exec(query, userID, commentID)
	return err
}

// GetPostLikeCounts returns like and dislike counts for a post
func (s *LikesService) GetPostLikeCounts(postID int) (likes int, dislikes int, err error) {
	query := `
		SELECT 
			SUM(CASE WHEN is_like = TRUE THEN 1 ELSE 0 END) as likes,
			SUM(CASE WHEN is_like = FALSE THEN 1 ELSE 0 END) as dislikes
		FROM post_likes
		WHERE post_id = ?`

	err = s.db.QueryRow(query, postID).Scan(&likes, &dislikes)
	if err == sql.ErrNoRows {
		return 0, 0, nil
	}
	return likes, dislikes, err
}

// GetUserPostVote returns the user's vote on a post (nil = no vote, true = like, false = dislike)
func (s *LikesService) GetUserPostVote(userID, postID int) (*bool, error) {
	query := `SELECT is_like FROM post_likes WHERE user_id = ? AND post_id = ?`

	var isLike bool
	err := s.db.QueryRow(query, userID, postID).Scan(&isLike)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &isLike, nil
}

// GetUserCommentVote returns the user's vote on a comment
func (s *LikesService) GetUserCommentVote(userID, commentID int) (*bool, error) {
	query := `SELECT is_like FROM comment_likes WHERE user_id = ? AND comment_id = ?`

	var isLike bool
	err := s.db.QueryRow(query, userID, commentID).Scan(&isLike)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &isLike, nil
}
