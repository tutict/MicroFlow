# MicroFlow 快速启动指南

本指南帮助你快速启动 MicroFlow 项目进行开发或演示。

## 一键启动脚本

项目提供了跨平台的一键启动脚本：

- **Windows**: `start.ps1`
- **Linux/macOS**: `start.sh`

## 使用方法

### Windows (PowerShell)

```powershell
# 开发模式 - 启动后端或前端
.\start.ps1 dev

# 生产模式 - 使用 Docker Compose
.\start.ps1 prod

# 停止服务
.\start.ps1 stop

# 清理环境 (删除容器和数据)
.\start.ps1 clean

# 跳过构建步骤
.\start.ps1 dev -SkipBuild

# 显示详细输出
.\start.ps1 dev -Verbose
```

### Linux/macOS (Bash)

```bash
# 开发模式 - 启动后端或前端
./start.sh dev

# 生产模式 - 使用 Docker Compose
./start.sh prod

# 停止服务
./start.sh stop

# 清理环境 (删除容器和数据)
./start.sh clean

# 跳过构建步骤
./start.sh dev --skip-build

# 显示详细输出
./start.sh dev --verbose
```

## 开发模式

启动开发模式时，脚本会提供三个选项：

### 1. 仅启动后端 (推荐先启动)

- 使用 Quarkus dev mode
- 支持热重载
- 访问地址: http://localhost:8080
- 健康检查: http://localhost:8080/api/v1/system/health

### 2. 仅启动前端

- 使用 Flutter 运行在 Chrome
- 自动连接到后端 (localhost:8080)
- Flutter 会自动分配端口

### 3. 同时启动后端和前端

- 在两个新终端窗口中分别启动后端和前端
- 自动等待后端启动完成后再启动前端
- 适合快速开始开发

## 生产模式

使用 Docker Compose 启动完整的生产环境：

```powershell
# Windows
.\start.ps1 prod

# Linux/macOS
./start.sh prod
```

访问地址：
- 前端: http://localhost:3000
- 后端: http://localhost:8080
- 健康检查: http://localhost:8080/api/v1/system/health

查看日志：
```bash
docker compose logs -f
```

## 环境要求

### 开发模式

- **Java**: JDK 21+
- **Maven**: 3.9+
- **Flutter**: 3+
- **Dart**: 3+

### 生产模式

- **Docker**: 最新版本
- **Docker Compose**: V2+

## 首次启动

脚本会自动执行以下初始化操作：

1. 检查环境依赖
2. 从 `.env.example` 创建 `.env` 文件 (如果不存在)
3. 创建数据目录 (`ops/docker/backend/data` 和 `ops/docker/backend/db`)

**重要提示**: 首次启动后，请检查并修改 `.env` 文件中的敏感配置：

```env
# 请替换为强随机密钥
MICROFLOW_JWT_SECRET=replace-with-a-long-random-jwt-secret

# 请替换为 Base64 编码的 32 字节 AES 密钥
MICROFLOW_CRYPTO_SECRET=ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=
```

## 常见使用场景

### 场景 1: 前端开发

```powershell
# 1. 启动后端
.\start.ps1 dev
# 选择: 1 (仅启动后端)

# 2. 在另一个终端启动前端
.\start.ps1 dev -SkipBuild
# 选择: 2 (仅启动前端)
```

### 场景 2: 后端开发

```powershell
# 1. 启动后端 (带编译)
.\start.ps1 dev
# 选择: 1 (仅启动后端)

# 2. Quarkus dev mode 支持热重载，修改代码会自动重新编译
```

### 场景 3: 全栈开发

```powershell
# 一键启动后端和前端 (自动打开两个终端窗口)
.\start.ps1 dev
# 选择: 3 (同时启动后端和前端)
```

### 场景 4: 演示或测试

```powershell
# 使用 Docker Compose 启动完整环境
.\start.ps1 prod

# 访问前端: http://localhost:3000
# 访问后端: http://localhost:8080
```

### 场景 5: 清理环境

```powershell
# 停止所有服务并清理数据
.\start.ps1 clean

# 根据提示选择是否删除数据库文件
```

## 配对连接

首次使用时，需要进行前后端配对：

1. 启动后端后，查看控制台输出的配对码 (Pairing Code)
2. 在前端界面输入后端地址和配对码
3. 完成配对后，连接信息会保存到本地安全存储

示例：
```
后端地址: http://localhost:8080
配对码: ABC123 (示例，实际以控制台输出为准)
```

## 故障排查

### 端口占用

如果端口被占用，可以修改 `.env` 文件中的端口配置：

```env
MICROFLOW_BACKEND_PORT=8080   # 后端端口
MICROFLOW_FRONTEND_PORT=3000  # 前端端口 (生产模式)
```

### Java 版本问题

确保使用 Java 21+：

```bash
java -version
# 应显示 java version "21.x.x" 或更高
```

### Flutter 依赖问题

手动清理并重新安装依赖：

```bash
cd frontend
flutter clean
flutter pub get
```

### Docker 构建失败

清理 Docker 缓存并重新构建：

```bash
docker system prune -a
.\start.ps1 prod
```

## 更多信息

- 完整文档: [README.md](README.md)
- 部署文档: [DEPLOYMENT.md](DEPLOYMENT.md)
- 前端说明: [frontend/README.md](frontend/README.md)

## 快捷命令参考

| 操作 | Windows | Linux/macOS |
|------|---------|-------------|
| 开发模式 | `.\start.ps1 dev` | `./start.sh dev` |
| 生产模式 | `.\start.ps1 prod` | `./start.sh prod` |
| 停止服务 | `.\start.ps1 stop` | `./start.sh stop` |
| 清理环境 | `.\start.ps1 clean` | `./start.sh clean` |
| 跳过构建 | `.\start.ps1 dev -SkipBuild` | `./start.sh dev --skip-build` |
| 详细输出 | `.\start.ps1 dev -Verbose` | `./start.sh dev --verbose` |
