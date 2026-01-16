package middleware

import (
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type IPRateLimiter struct {
	ips map[string]*rate.Limiter
	mu  sync.RWMutex
	rate.Limiter
}

func NewIPRateLimiter(r rate.Limit, b int) *IPRateLimiter {
	return &IPRateLimiter{
		ips: make(map[string]*rate.Limiter),
		Limiter: rate.NewLimiter(r, b),
	}
}

func (i *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
	i.mu.Lock()
	defer i.mu.Unlock()

	limiter, exists := i.ips[ip]
	if !exists {
		limiter = rate.NewLimiter(i.Limit, i.Burst())
		i.ips[ip] = limiter
	}

	return limiter
}

func (i *IPRateLimiter) Allow(ip string) bool {
	return i.GetLimiter(ip).Allow()
}

var (
	loginLimiter     *IPRateLimiter
	loginLimiterOnce sync.Once
)

func GetLoginLimiter() *IPRateLimiter {
	loginLimiterOnce.Do(func() {
		loginLimiter = NewIPRateLimiter(rate.Limit(3), 3)
	})
	return loginLimiter
}

func RateLimitMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		limiter := GetLoginLimiter()

		if !limiter.Allow(ip) {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"success": false,
				"msg":     "登录尝试过于频繁，请稍后再试",
			})
			return
		}

		c.Next()
	}
}
