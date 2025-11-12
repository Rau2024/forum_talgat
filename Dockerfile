# Multi-stage build for smaller image size
# Stage 1: Build the Go application
FROM golang:1.24.6-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git gcc musl-dev sqlite-dev

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
# CGO_ENABLED=1 is required for sqlite
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o forum ./cmd/server/main.go

# Verify binary was created (simple check without 'file' command)
RUN ls -lh /app/forum

# Stage 2: Create minimal runtime image
FROM alpine:latest

# Install runtime dependencies (including sqlite CLI for database access)
RUN apk --no-cache add ca-certificates sqlite-libs tzdata sqlite

# Set timezone to Kazakhstan (Almaty)
ENV TZ=Asia/Almaty
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create non-root user for security
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/forum .

# Make binary executable
RUN chmod +x ./forum

# Copy necessary files
COPY --chown=appuser:appuser web/ ./web/
COPY --chown=appuser:appuser go.mod ./

# Create directory for database with proper permissions BEFORE switching user
RUN mkdir -p /app/data && chown -R appuser:appuser /app/data

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Set default environment variables
ENV PORT=8080
ENV DATABASE_URL=/app/data/forum.db

# Run the application directly
CMD ["./forum"]