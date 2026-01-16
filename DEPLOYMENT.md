# 🐳 x-ui Docker 部署指南

## 目录

- [快速开始](#快速开始)
- [前置要求](#前置要求)
- [部署步骤](#部署步骤)
- [配置说明](#配置说明)
- [常用命令](#常用命令)
- [故障排除](#故障排除)

---

## 🚀 快速开始

### 使用一键脚本（推荐）

```bash
chmod +x deploy.sh
./deploy.sh
```

### 手动部署

```bash
# 1. 构建镜像
docker build -t x-ui:latest .

# 2. 创建数据目录
mkdir -p data cert logs

# 3. 运行容器
docker run -d \
  --name x-ui \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/data:/etc/x-ui/ \
  -v $(pwd)/cert:/root/cert/ \
  -v $(pwd)/logs:/var/log/x-ui/ \
  -e TZ=Asia/Shanghai \
  x-ui:latest
```

---

## 📋 前置要求

### 1. Docker 安装

**Ubuntu:**
```bash
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

**CentOS:**
```bash
sudo yum install docker docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

**Windows/macOS:**
从 [Docker官网](https://www.docker.com/products/docker-desktop) 下载安装

### 2. 检查系统资源

```bash
# 检查Docker版本
docker --version

# 检查可用内存
free -m

# 检查可用磁盘空间
df -h
```

**最低要求:**
- 内存: 512MB+
- 磁盘: 1GB+
- CPU: 1核心

---

## 🔧 部署步骤

### 步骤1：准备项目

```bash
# 克隆项目
git clone https://github.com/whj2015/x-ui.git
cd x-ui

# 确保bin目录有xray文件
ls -lh bin/
```

**如果bin目录为空，需要下载xray:**
```bash
# 下载xray (以v1.4.2为例)
wget https://github.com/XTLS/Xray-core/releases/download/v1.4.2/Xray-linux-64.zip

# 解压
unzip Xray-linux-64.zip

# 移动到bin目录
mv xray bin/xray-linux-amd64

# 赋予执行权限
chmod +x bin/xray-linux-amd64
```

### 步骤2：构建Docker镜像

```bash
# 构建镜像（使用优化后的Dockerfile）
docker build -t x-ui:latest .

# 验证镜像
docker images x-ui
```

**镜像信息:**
- 大小: ~50MB
- 基于: alpine:3.19
- 非root用户运行

### 步骤3：准备数据目录

```bash
# 创建必要目录
mkdir -p data cert logs

# 设置权限
chmod -R 755 data cert logs
```

**目录说明:**
- `data/`: 存储数据库和配置
- `cert/`: 存储SSL证书
- `logs/`: 存储日志文件

### 步骤4：运行容器

```bash
# 使用host网络模式（推荐）
docker run -d \
  --name x-ui \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/data:/etc/x-ui/ \
  -v $(pwd)/cert:/root/cert/ \
  -v $(pwd)/logs:/var/log/x-ui/ \
  -e TZ=Asia/Shanghai \
  -e XUI_LOG_LEVEL=info \
  x-ui:latest
```

**参数说明:**

| 参数 | 说明 |
|------|------|
| `-d` | 后台运行 |
| `--name x-ui` | 容器名称 |
| `--restart unless-stopped` | 自动重启 |
| `--network host` | 使用主机网络 |
| `-v` | 数据卷挂载 |
| `-e` | 环境变量 |

### 步骤5：验证部署

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs x-ui

# 测试访问
curl http://localhost:54321/
```

---

## ⚙️ 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `TZ` | Asia/Shanghai | 时区设置 |
| `XUI_LOG_LEVEL` | info | 日志级别 (debug/info/warn/error) |
| `XUI_DEBUG` | false | 调试模式 |

### 使用docker-compose部署

创建 `docker-compose.yml`:

```yaml
version: '3.8'

services:
  x-ui:
    image: x-ui:latest
    container_name: x-ui
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./data:/etc/x-ui/
      - ./cert:/root/cert/
      - ./logs:/var/log/x-ui/
    environment:
      - TZ=Asia/Shanghai
      - XUI_LOG_LEVEL=info
    ports:
      - "54321:54321"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:54321/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

启动:
```bash
docker-compose up -d
```

---

## 📚 常用命令

### 容器管理

```bash
# 启动容器
docker start x-ui

# 停止容器
docker stop x-ui

# 重启容器
docker restart x-ui

# 删除容器
docker rm x-ui

# 查看容器状态
docker ps | grep x-ui
```

### 日志查看

```bash
# 查看实时日志
docker logs -f x-ui

# 查看最近100行日志
docker logs --tail 100 x-ui

# 查看错误日志
docker logs x-ui 2>&1 | grep -i error
```

### 进入容器

```bash
# 使用bash进入容器
docker exec -it x-ui /bin/sh

# 使用sh进入容器
docker exec -it x-ui sh
```

### 数据备份

```bash
# 备份数据库
cp data/x-ui.db data/x-ui.db.$(date +%Y%m%d)

# 备份整个数据目录
tar -czvf x-ui-backup-$(date +%Y%m%d).tar.gz data/ cert/
```

### 更新版本

```bash
# 1. 拉取最新代码
git pull

# 2. 重新构建镜像
docker build -t x-ui:latest .

# 3. 停止旧容器
docker stop x-ui && docker rm x-ui

# 4. 启动新容器（数据会自动保留）
docker run -d ... (同上)
```

---

## 🔧 故障排除

### 1. 容器无法启动

```bash
# 查看启动日志
docker logs x-ui

# 常见原因:
# - 端口被占用
# - 权限问题
# - 磁盘空间不足
```

### 2. 无法访问Web界面

```bash
# 检查端口是否开放
netstat -tlnp | grep 54321

# 检查防火墙
sudo ufw status

# 测试本地连接
curl http://localhost:54321/
```

### 3. 数据库错误

```bash
# 检查数据库文件
ls -lh data/

# 修复权限
chmod 755 data/
chmod 644 data/x-ui.db
```

### 4. SSL证书问题

```bash
# 检查证书目录
ls -la cert/

# 证书格式要求:
# - cert.pem: SSL证书
# - private.key: 私钥
```

### 5. 内存不足

```bash
# 检查内存使用
free -m

# 增加swap (如果需要)
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 6. 查看完整系统日志

```bash
# Docker日志
journalctl -u docker -f

# 容器资源使用
docker stats x-ui
```

---

## 🔒 安全建议

### 1. 修改默认密码

首次登录后立即修改admin密码。

### 2. 配置SSL证书

```bash
# 放入证书文件
cert/cert.pem
cert/private.key

# 重启容器
docker restart x-ui
```

### 3. 启用防火墙

```bash
# Ubuntu
sudo ufw allow 54321
sudo ufw enable
```

### 4. 定期备份

```bash
# 添加cron任务
crontab -e

# 每天凌晨2点备份
0 2 * * * tar -czvf /backup/x-ui-$(date +\%Y\%m\%d).tar.gz /path/to/x-ui/data
```

---

## 📊 监控

### 容器健康检查

```bash
# 查看容器健康状态
docker inspect --format='{{.State.Health.Status}}' x-ui

# 查看健康检查日志
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' x-ui
```

### 资源监控

```bash
# CPU和内存使用
docker stats x-ui

# 磁盘使用
df -h
du -sh data/
```

---

## 📞 获取帮助

- **项目地址**: https://github.com/whj2015/x-ui
- **Issues**: https://github.com/whj2015/x-ui/issues
- **Wiki**: https://github.com/whj2015/x-ui/wiki

---

## 📝 更新日志

### v1.0.0 (当前版本)
- ✅ 密码bcrypt哈希存储
- ✅ 登录频率限制
- ✅ 安全响应头
- ✅ Cookie HttpOnly+SameSite
- ✅ 输入验证
- ✅ 文件权限加固
- ✅ 依赖安全更新
- ✅ Docker镜像优化

---

**🎉 部署完成！访问 http://your-server:54321 开始使用**
