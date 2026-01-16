package service

import (
	"errors"
	"x-ui/database"
	"x-ui/database/model"
	"x-ui/logger"
	"x-ui/util/validation"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type UserService struct {
}

func (s *UserService) GetFirstUser() (*model.User, error) {
	db := database.GetDB()

	user := &model.User{}
	err := db.Model(model.User{}).
		First(user).
		Error
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (s *UserService) HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func (s *UserService) CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func (s *UserService) IsHashedPassword(password string) bool {
	return len(password) == 60 && password[0:2] == "$2"
}

func (s *UserService) CheckUser(username string, password string) *model.User {
	db := database.GetDB()

	user := &model.User{}
	err := db.Model(model.User{}).
		Where("username = ?", username).
		First(user).
		Error
	if err == gorm.ErrRecordNotFound {
		return nil
	} else if err != nil {
		logger.Warning("check user err:", err)
		return nil
	}

	if s.IsHashedPassword(user.Password) {
		if s.CheckPassword(password, user.Password) {
			return user
		}
	} else {
		if user.Password == password {
			return user
		}
	}
	return nil
}

func (s *UserService) UpdateUser(id int, username string, password string) error {
	db := database.GetDB()
	return db.Model(model.User{}).
		Where("id = ?", id).
		Update("username", username).
		Update("password", password).
		Error
}

func (s *UserService) UpdateFirstUser(username string, password string) error {
	if err := validation.ValidateUsername(username); err != nil {
		return err
	}
	if err := validation.ValidatePassword(password); err != nil {
		return err
	}

	if username == "" {
		return errors.New("username can not be empty")
	} else if password == "" {
		return errors.New("password can not be empty")
	}
	db := database.GetDB()
	user := &model.User{}
	err := db.Model(model.User{}).First(user).Error
	if database.IsNotFound(err) {
		hashedPassword, err := s.HashPassword(password)
		if err != nil {
			return errors.New("密码加密失败: " + err.Error())
		}
		user.Username = username
		user.Password = hashedPassword
		return db.Model(model.User{}).Create(user).Error
	} else if err != nil {
		return err
	}

	hashedPassword, err := s.HashPassword(password)
	if err != nil {
		return errors.New("密码加密失败: " + err.Error())
	}
	user.Username = username
	user.Password = hashedPassword
	return db.Save(user).Error
}
