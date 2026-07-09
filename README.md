# 微澜协作

**微澜协作（MicroFlow）** 是一个面向本地部署与内网协作场景的轻量级 AI 协作工作台。项目面向一人公司、三三制小团队和私有化协作场景，整合账号登录、工作区/频道、实时聊天、Agent 调用、知识库检索、运行诊断、基础会计和前后端配对连接能力，采用本地优先、轻量部署、边界可控的设计思路。

## 项目概览

- **中文名称**：微澜协作
- **英文名称**：MicroFlow
- **项目定位**：本地优先的轻量级 AI 协作工作台
- **业务方向**：团队沟通、Agent 协作、知识沉淀、基础会计与内网部署
- **核心能力**：工作区协作、实时消息、Agent 调用、知识库检索、一次性配对连接、本地持久化与基础安全控制
- **适合场景**：个人演示、小团队协作、内网工具、企业原型、全栈项目展示

## 核心功能

- 账号注册、登录、JWT 鉴权与会话保持
- 工作区、频道、成员、会话和消息管理
- WebSocket 实时消息同步与连接状态展示
- Agent 列表、运行记录、角色策略和诊断信息展示
- 知识库资料上传、检索和协作上下文沉淀
- 基础会计模块，覆盖科目、凭证和试算平衡等场景
- 前后端分离场景下的一次性 Pairing Code / 二维码配对连接
- 基于 SQLite 的轻量级本地持久化
- 一键启动本地 debug 预览环境

## 设计取向

微澜协作强调“轻量、本地、协作、可控”：

- **轻量**：使用 SQLite 和本地进程即可完成核心协作链路，降低部署门槛。
- **本地**：优先支持单机与内网环境，减少对公网服务的依赖。
- **协作**：围绕工作区、频道、实时聊天、Agent 和知识库组织团队上下文。
- **可控**：通过配对码、WebSocket Ticket、Host 校验、CORS 收敛、登录限流和消息加密约束访问边界。
- **可扩展**：后端按认证、工作区、消息、Agent、知识库、会计和诊断等边界拆分，便于继续扩展业务模块。

## 技术栈

| 分层 | 技术方案 |
| --- | --- |
| 后端 | Quarkus 3.35、RESTEasy、WebSocket、Hibernate Validator、JDBC |
| 数据存储 | SQLite |
| 客户端 | Flutter、Dart 3、Riverpod |
| 通信 | HTTP API、WebSocket |
| 安全 | JWT、WebSocket Ticket、登录限流、Host/CORS 校验、AES-GCM 消息加密 |
| 部署 | 本地启动、Docker Compose、GraalVM Native Image |

## 仓库结构

```text
MicroFlow
├─ backend/                         # Quarkus 后端服务
├─ frontend/                        # Flutter 跨平台客户端
├─ ops/                             # 运维与辅助脚本
├─ scripts/                         # 本地开发脚本
│  ├─ start-debug-preview.ps1       # Windows 一键 debug 预览脚本
│  └─ start-debug-preview.bat       # 双击启动包装脚本
├─ docker-compose.yml               # 本地部署编排
├─ DEPLOYMENT.md                    # 部署文档
└─ README.md                        # 项目说明
```

## 主要模块

### 后端服务

后端负责认证、配对连接、工作区协作、实时消息、Agent 运行、知识库检索和基础会计能力。

- 路径：`backend/`
- 技术关键词：`Quarkus`、`WebSocket`、`SQLite`、`JWT`
- 主要能力：Auth / JWT、Bootstrap Pairing、Workspace / Channels / Members、Message Service、Agent Run Service、Agent Diagnostics、Knowledge Base、Accounting

### Flutter 客户端

客户端负责跨平台界面、连接建立、实时消息、本地连接配置和业务页面展示。

- 路径：`frontend/`
- 技术关键词：`Flutter`、`Riverpod`、`web_socket_channel`
- 主要能力：首次连接页、登录页与会话门禁、工作区首页、频道列表、消息面板、Agent 面板、知识库、会计页面、Agent runs / diagnostics 页面

### 配对连接机制

配对连接用于解决前后端分离部署下的首次连接问题。

- 后端生成一次性配对码与二维码内容
- 前端输入服务器地址和配对码完成握手
- 后端返回 `serverOrigin`、`apiBaseUrl`、`wsBaseUrl`
- 前端保存连接配置后进入登录流程
- 配对入口受本地访问、Host 信任边界和有效期约束

## 快速启动

### 环境准备

- JDK 21+
- Maven 3.9+
- Flutter 3+
- Docker（可选，用于本地编排）

### 一键 debug 预览

Windows 环境可直接运行：

```powershell
.\scripts\start-debug-preview.ps1
```

或双击/执行：

```bat
.\scripts\start-debug-preview.bat
```

默认启动地址：

```text
后端服务：http://127.0.0.1:8080
健康检查：http://127.0.0.1:8080/api/v1/system/health
前端预览：http://127.0.0.1:3000
```

常用参数：

```powershell
.\scripts\start-debug-preview.ps1 -BackendPort 8081 -FrontendPort 3001
.\scripts\start-debug-preview.ps1 -SeedDemo
.\scripts\start-debug-preview.ps1 -NoBrowser
.\scripts\start-debug-preview.ps1 -SkipPubGet
```

脚本会自动为前端注入：

```text
MICROFLOW_API_BASE_URL=http://127.0.0.1:8080/api/v1
MICROFLOW_WS_BASE_URL=ws://127.0.0.1:8080/ws
```

脚本日志默认写入：

```text
.codex-tmp/debug-preview/
```

### 手动启动后端

```powershell
cd backend
..\mvnw.cmd quarkus:dev
```

默认地址：

```text
http://localhost:8080
```

健康检查：

```text
GET /api/v1/system/health
```

### 手动启动前端

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

开发阶段也可以显式指定后端地址：

```powershell
flutter run -d chrome `
  --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 `
  --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws
```

## 关键接口

- `POST /api/v1/bootstrap/pair`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/workspaces`
- `GET /api/v1/workspaces/{workspaceId}/channels`
- `GET /api/v1/channels/{channelId}/messages`
- `POST /api/v1/channels/{channelId}/messages`
- `GET /api/v1/agents`
- `GET /api/v1/agent-runs`
- `GET /api/v1/agent-diagnostics`

## 配置说明

- Agent provider 配置支持以下加载顺序：`MICROFLOW_AGENT_CONFIG_JSON`、`MICROFLOW_AGENT_CONFIG_PATH`、Quarkus 配置 `microflow.agent.openclaw-*`、`OPENCLAW_ENDPOINT_URL` + `OPENCLAW_AGENT_KEYS`、fallback `mock-openclaw`
- 是否生成演示账号由 `MICROFLOW_SEED_DEMO_ENABLED` 控制。
- 本地 debug 预览脚本默认启用 `MICROFLOW_ALLOW_INSECURE_DEFAULT_SECRETS=true`，仅用于开发环境。
- 生产或正式部署应显式配置 `microflow.jwt.secret` 和 `microflow.crypto.secret`。
- 推荐优先使用配对流程，而不是在前端写死服务地址。

## 安全收敛

- 使用一次性 Pairing Code / 二维码完成首次连接
- 使用 WebSocket Ticket 限制实时连接认证边界
- 收紧配对访问逻辑与 Host 信任边界
- 限制 CORS 来源为本地或显式配置来源
- 为登录请求增加限流保护
- 使用 AES-GCM 加密消息内容
- 对消息输入长度与列表上限进行校验
- 清理前端页面中的残留调试代码与默认回退逻辑

## 项目亮点

- **本地优先**：单机即可完成登录、配对、聊天、Agent、知识库和基础会计演示链路。
- **前后端清晰分离**：后端提供稳定 HTTP/WebSocket 接口，前端通过环境参数或配对流程建立连接。
- **内网协作友好**：Pairing Code / 二维码降低首次连接成本，适合小团队局域网部署。
- **可观测性友好**：健康检查、诊断页、Agent 运行记录和脚本日志便于定位问题。
- **部署路径完整**：支持本地开发、Docker Compose 和后续 Native Image 扩展。

## 相关文档

- 部署文档：[DEPLOYMENT.md](DEPLOYMENT.md)
- 前端说明：[frontend/README.md](frontend/README.md)

