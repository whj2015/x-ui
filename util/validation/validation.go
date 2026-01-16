package util

import (
	"regexp"
	"strings"
	"unicode"
)

type ValidationError struct {
	Field   string
	Message string
}

func (e *ValidationError) Error() string {
	return e.Message
}

func ValidateUsername(username string) error {
	if len(username) < 3 {
		return &ValidationError{
			Field:   "username",
			Message: "用户名长度必须至少为3个字符",
		}
	}
	if len(username) > 32 {
		return &ValidationError{
			Field:   "username",
			Message: "用户名长度不能超过32个字符",
		}
	}
	if !regexp.MustCompile(`^[a-zA-Z0-9_]+$`).MatchString(username) {
		return &ValidationError{
			Field:   "username",
			Message: "用户名只能包含字母、数字和下划线",
		}
	}
	return nil
}

func ValidatePassword(password string) error {
	if len(password) < 8 {
		return &ValidationError{
			Field:   "password",
			Message: "密码长度必须至少为8个字符",
		}
	}
	if len(password) > 128 {
		return &ValidationError{
			Field:   "password",
			Message: "密码长度不能超过128个字符",
		}
	}

	hasUpper := false
	hasLower := false
	hasDigit := false
	hasSpecial := false

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsDigit(char):
			hasDigit = true
		case strings.ContainsRune("!@#$%^&*()_+-=[]{}|;':\",./<>?", char):
			hasSpecial = true
		}
	}

	if !hasUpper {
		return &ValidationError{
			Field:   "password",
			Message: "密码必须包含至少一个大写字母",
		}
	}
	if !hasLower {
		return &ValidationError{
			Field:   "password",
			Message: "密码必须包含至少一个小写字母",
		}
	}
	if !hasDigit {
		return &ValidationError{
			Field:   "password",
			Message: "密码必须包含至少一个数字",
		}
	}
	if !hasSpecial {
		return &ValidationError{
			Field:   "password",
			Message: "密码必须包含至少一个特殊字符",
		}
	}

	return nil
}

func ValidatePort(port int) error {
	if port < 1 || port > 65535 {
		return &ValidationError{
			Field:   "port",
			Message: "端口号必须在1-65535之间",
		}
	}
	return nil
}

func ValidateRemark(remark string) error {
	if len(remark) > 255 {
		return &ValidationError{
			Field:   "remark",
			Message: "备注长度不能超过255个字符",
		}
	}
	return nil
}
