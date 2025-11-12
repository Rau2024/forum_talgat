package services

import (
	"database/sql"
	"errors"
	"strings"

	"forum/internal/models"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type UserService struct {
	db *sql.DB
}

func NewUserService(db *sql.DB) *UserService {
	return &UserService{db: db}
}

func (s *UserService) CreateUser(username, email, password string) (*models.User, error) {
	// Hash password with bcrypt
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	// Generate UUID for unique identification
	userID := uuid.New().String()

	// Insert user
	query := `
		INSERT INTO users (uuid, username, email, password_hash, created_at, updated_at)
		VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`

	result, err := s.db.Exec(query, userID, username, email, string(hashedPassword))
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE constraint failed") {
			if strings.Contains(err.Error(), "username") {
				return nil, errors.New("username already exists")
			}
			if strings.Contains(err.Error(), "email") {
				return nil, errors.New("email already exists")
			}
		}
		return nil, err
	}

	id, _ := result.LastInsertId()

	return &models.User{
		ID:       int(id),
		UUID:     userID,
		Username: username,
		Email:    email,
	}, nil
}

func (s *UserService) AuthenticateUser(username, password string) (*models.User, error) {
	var user models.User
	query := `SELECT id, uuid, username, email, password_hash, is_admin, created_at 
			  FROM users WHERE username = ? OR email = ?`

	err := s.db.QueryRow(query, username, username).Scan(
		&user.ID, &user.UUID, &user.Username, &user.Email,
		&user.PasswordHash, &user.IsAdmin, &user.CreatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("invalid username or password")
		}
		return nil, err
	}

	// Verify password with bcrypt
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, errors.New("invalid username or password")
	}

	return &user, nil
}

func (s *UserService) GetUserByID(id int) (*models.User, error) {
	var user models.User
	var avatarURL sql.NullString

	query := `SELECT id, uuid, username, email, avatar_url, is_admin, created_at 
			  FROM users WHERE id = ?`

	err := s.db.QueryRow(query, id).Scan(
		&user.ID, &user.UUID, &user.Username, &user.Email,
		&avatarURL, &user.IsAdmin, &user.CreatedAt,
	)
	if err != nil {
		return nil, err
	}

	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}

	return &user, nil
}
