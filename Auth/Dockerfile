









# Build stage
FROM golang:1.23-alpine AS builder
ENV GOPROXY=https://goproxy.cn,direct 
ENV GO111MODULE="on" 

COPY go.mod .
COPY go.sum .
RUN go mod download
WORKDIR /app
COPY . .
# RUN go mod vendor
RUN CGO_ENABLED=0 GOOS=linux go build -o auth-app ./cmd/main.go

# Runtime stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/auth-app .
COPY envs/ envs/

EXPOSE 8080 50051
CMD ["./auth-app"]