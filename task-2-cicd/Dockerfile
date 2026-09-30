# Stage 1: Build static binary
FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY app/go.mod ./
COPY app/*.go ./

# Compile static binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o rova-api .

# Stage 2: Minimal non-root runtime
FROM alpine:3.20

# Create non-root user
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/rova-api .

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["/app/rova-api"]
