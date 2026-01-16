# 构建阶段：使用Go编译器
FROM golang:1.21-alpine AS builder

# 安装git用于下载依赖
RUN apk add --no-cache git

WORKDIR /app

# 先复制go.mod和go.sum以利用缓存
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# 复制源代码并构建
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o x-ui main.go

# 运行阶段：使用轻量级Alpine
FROM alpine:3.19

# 安装必要的运行时包
RUN apk add --no-cache \
    ca-certificates \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /root

# 从构建阶段复制二进制文件
COPY --from=builder /app/x-ui .

# 确保x-ui可执行
RUN chmod +x x-ui

# 创建必要目录
RUN mkdir -p /etc/x-ui /root/cert /var/log/x-ui

# 创建非root用户（增强安全性）
RUN addgroup -g 1000 xui && \
    adduser -u 1000 -G xui -s /bin/sh -D xui && \
    chown -R xui:xui /etc/x-ui /root/cert /var/log/x-ui

# 切换到非root用户
USER xui

# 暴露端口
EXPOSE 54321

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:54321/ || exit 1

# 默认命令
CMD ["./x-ui"]
