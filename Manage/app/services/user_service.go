package services

import (
	"errors"
	"manage/app/db"
	"manage/app/models"
)

type UserService struct {
	db *db.Database
}

func NewUserService(db *db.Database) *UserService {
	return &UserService{db: db}
}

func (s *UserService) GetUsers(page, pageSize int) (*models.PaginatedUsers, error) {
	offset := (page - 1) * pageSize

	// Get total count
	var totalCount int
	err := s.db.QueryRow("SELECT COUNT(*) FROM users").Scan(&totalCount)
	if err != nil {
		return nil, err
	}

	// Get paginated users
	rows, err := s.db.Query("SELECT id, email, email FROM users LIMIT ? OFFSET ?", pageSize, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		if err := rows.Scan(&user.Id, &user.Email, &user.Email); err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	return &models.PaginatedUsers{
		Users:      users,
		TotalCount: totalCount,
		Page:       page,
		PageSize:   pageSize,
	}, nil
}

func (s *UserService) DeleteUser(identifier string) error {
	// Try to delete by email first
	result, err := s.db.Exec("DELETE FROM users WHERE email = ?", identifier)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		// If no rows affected by email, try by ID
		result, err = s.db.Exec("DELETE FROM users WHERE id = ?", identifier)
		if err != nil {
			return err
		}

		rowsAffected, err = result.RowsAffected()
		if err != nil {
			return err
		}

		if rowsAffected == 0 {
			return errors.New("user not found")
		}
	}

	return nil
}
