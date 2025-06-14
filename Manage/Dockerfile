# Build stage
FROM golang:1.23-alpine AS builder
ENV GO111MODULE="on" \
    GOPROXY="direct"  

WORKDIR /app

# Copy dependency files and vendored modules
COPY go.mod go.sum ./
COPY vendor ./vendor

# Copy application code
COPY . .

# Build using local vendor directory
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o manage-app ./cmd/main.go

# Runtime stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/manage-app .
COPY app.env app.env
EXPOSE 8080 50051
CMD ["./manage-app"]