package services

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"errors"
	"time"

	"forum/internal/models"
)

type SessionService struct {
	db *sql.DB
}

func NewSessionService(db *sql.DB) *SessionService {
	return &SessionService{db: db}
}

// Create a new session (and delete any existing sessions for this user)
func (s *SessionService) CreateSession(userID int) (string, error) {
	// First, delete any existing sessions for this user
	deleteQuery := `DELETE FROM sessions WHERE user_id = ?`
	_, err := s.db.Exec(deleteQuery, userID)
	if err != nil {
		return "", err
	}

	// Generate random session token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return "", err
	}
	token := base64.URLEncoding.EncodeToString(tokenBytes)

	// Store new session in database
	query := `
		INSERT INTO sessions (token, user_id, expires_at, created_at)
		VALUES (?, ?, ?, CURRENT_TIMESTAMP)`

	expiresAt := time.Now().Add(24 * time.Hour) // 24 hour sessions
	_, err = s.db.Exec(query, token, userID, expiresAt)
	if err != nil {
		return "", err
	}

	return token, nil
}

// Get user by session token
func (s *SessionService) GetUserByToken(token string) (*models.User, error) {
	query := `
		SELECT u.id, u.uuid, u.username, u.email, u.avatar_url, u.is_admin, u.created_at
		FROM users u
		JOIN sessions s ON u.id = s.user_id
		WHERE s.token = ? AND s.expires_at > CURRENT_TIMESTAMP`

	var user models.User
	var avatarURL sql.NullString // Use sql.NullString for nullable fields

	err := s.db.QueryRow(query, token).Scan(
		&user.ID, &user.UUID, &user.Username, &user.Email,
		&avatarURL, &user.IsAdmin, &user.CreatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("invalid or expired session")
		}
		return nil, err
	}

	// Convert sql.NullString to regular string
	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	} else {
		user.AvatarURL = ""
	}

	return &user, nil
}

// Delete session (logout)
func (s *SessionService) DeleteSession(token string) error {
	query := `DELETE FROM sessions WHERE token = ?`
	_, err := s.db.Exec(query, token)
	return err
}

// Clean expired sessions
func (s *SessionService) CleanExpiredSessions() error {
	query := `DELETE FROM sessions WHERE expires_at < CURRENT_TIMESTAMP`
	_, err := s.db.Exec(query)
	return err
}
