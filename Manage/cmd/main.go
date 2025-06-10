package main

import (
	"log"
	"manage/app/config"
	"manage/app/db"
	"manage/app/services"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig(".")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize database
	database, err := db.NewDatabase(&cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	// Initialize services
	userService := services.NewUserService(database)

	// Initialize Gin router
	r := gin.Default()

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// Auth management routes
	auth := r.Group("/auth")
	{
		// GET /auth/users - Get paginated list of users
		auth.GET("/users", func(c *gin.Context) {
			page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
			pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))

			if page < 1 {
				page = 1
			}
			if pageSize < 1 {
				pageSize = 10
			}

			users, err := userService.GetUsers(page, pageSize)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}

			c.JSON(http.StatusOK, users)
		})

		// DELETE /auth/user - Delete user by email or ID
		auth.DELETE("/user", func(c *gin.Context) {
			identifier := c.Query("identifier")
			if identifier == "" {
				c.JSON(http.StatusBadRequest, gin.H{"error": "identifier parameter is required"})
				return
			}

			err := userService.DeleteUser(identifier)
			if err != nil {
				status := http.StatusInternalServerError
				if err.Error() == "user not found" {
					status = http.StatusNotFound
				}
				c.JSON(status, gin.H{"error": err.Error()})
				return
			}

			c.JSON(http.StatusOK, gin.H{"message": "user deleted successfully"})
		})
	}

	// Start server
	port := cfg.ServerPort
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
