# Docker Deployment

MicroFlow 现在提供可直接落地的 Docker / Docker Compose 部署。

默认方案使用 JVM 容器镜像，不把 GraalVM native image 作为默认交付路径。原因很简单：JVM 镜像更稳定、跨平台更容易、CI/CD 和问题排查也更直接。仓库里保留的 GraalVM 配置仍然可以继续用于后续性能优化。

## 目录

- `backend/Dockerfile`: 后端镜像构建
- `frontend/Dockerfile`: Flutter Web 静态站点构建
- `frontend/nginx/default.conf`: 前端静态托管配置
- `docker-compose.yml`: 一键编排
- `.env.example`: 部署环境变量模板
- `ops/docker/backend/data`: Agent 配置和运行时数据目录
- `ops/docker/backend/db`: SQLite 数据目录

## 启动前准备

1. 复制环境变量模板

```powershell
Copy-Item .env.example .env
```

2. 至少修改下面两个密钥

- `MICROFLOW_JWT_SECRET`
- `MICROFLOW_CRYPTO_SECRET`

`MICROFLOW_CRYPTO_SECRET` 必须是 Base64 编码后的 AES 密钥，建议使用 32 字节随机值。

3. 如果不是本机 `localhost` 部署，必须同步修改这些地址

- `MICROFLOW_SERVER_ORIGIN`
- `MICROFLOW_API_BASE_URL`
- `MICROFLOW_WS_BASE_URL`
- `MICROFLOW_HTTP_ALLOWED_ORIGIN_PATTERNS`
- `MICROFLOW_WS_ALLOWED_ORIGIN_PATTERNS`

否则后端的配对返回地址和跨域校验会继续指向 `localhost`，前端就会连错地址或者被拦截。

## 一键启动

```powershell
docker compose up -d --build
```

启动后：

- 前端默认地址是 `http://localhost:3000`
- 后端默认地址是 `http://localhost:8080`
- 后端健康检查是 `http://localhost:8080/api/v1/system/health`
- 本机配对控制台是 `http://localhost:8080/api/v1/bootstrap/console`

首次进入前端后，按现有产品流程输入：

- Server URL: `http://localhost:8080`
- Pairing code: 后端日志里输出的一次性配对码

## 常用命令

查看日志：

```powershell
docker compose logs -f backend
docker compose logs -f frontend
```

停止服务：

```powershell
docker compose down
```

停止并删除持久化数据：

```powershell
docker compose down
Remove-Item -Recurse -Force .\ops\docker\backend\data\*
Remove-Item -Recurse -Force .\ops\docker\backend\db\*
```

## 持久化说明

- SQLite 数据库保存在 `ops/docker/backend/db`
- Agent 配置文件默认路径是 `ops/docker/backend/data/agents.json`
- 如果 `agents.json` 不存在，后端会回退到项目当前已有的 mock agent 行为

## OpenClaw 可选配置

如果你要把真实 Agent provider 接进来，可以在 `.env` 里设置：

- `OPENCLAW_ENDPOINT_URL`
- `OPENCLAW_CREDENTIAL`
- `OPENCLAW_AGENT_KEYS`

不设置时，系统会沿用当前项目里的 fallback / mock 策略。

## 生产化建议

- 现在的 Compose 适合单机、自托管、内网部署
- 如果要暴露到公网，建议前面再加反向代理和 HTTPS
- 如果后续要优化冷启动和内存占用，再补 GraalVM native 容器镜像更合适
