# Build stage
FROM golang:1.23-alpine AS builder
ENV GOPROXY=https://goproxy.cn,direct 
ENV GO111MODULE="on" 

COPY go.mod .
COPY go.sum .
RUN go mod download
WORKDIR /app

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o manage-app ./cmd/main.go
EXPOSE 8080

# Runtime stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/manage-app .
COPY app.env app.env

EXPOSE 8080 50051
CMD ["./manage-app"]