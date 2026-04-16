# MicroFlow

一个面向本地部署与内网协作场景的轻量级 AI 协作工作台，整合账号登录、工作区聊天、实时通信、Agent 调用、运行诊断和前后端配对连接能力。项目采用本地优先的设计思路，适合快速部署、快速演示和持续扩展。

## 项目概览

- 项目类型：本地优先的 AI 协作系统
- 业务方向：团队沟通、Agent 协作与内网部署型工作台
- 主要能力：工作区消息协作、Agent 调用、WebSocket 实时通信、前后端配对连接、本地安全存储
- 适合阅读对象：HR 初筛、后端开发、全栈开发、企业工具与协作平台方向面试官

## 核心功能

- 注册、登录与 JWT 鉴权
- 工作区、频道、成员和消息管理
- WebSocket 实时消息同步
- Agent 列表、运行记录、角色策略与诊断信息展示
- 前后端分离场景下的一次性配对连接
- 基于 SQLite 的轻量持久化
- 本地安全存储与连接信息保存

## 承担内容

- 完成协作系统的业务边界设计与后端模块划分
- 完成 Spring Boot 后端、Flutter 客户端与本地部署链路实现
- 完成配对码连接机制、登录流程和实时消息能力设计
- 完成 Agent 运行记录、诊断页和角色策略相关功能
- 完成登录限流、Host 校验、输入边界与本地安全存储等安全收敛工作

## 关键技术实现

- 使用 `Spring Boot + WebSocket + JDBC` 构建本地优先协作后端
- 使用 `SQLite` 降低部署门槛，支持单机和内网快速启动
- 使用一次性 `pairing code` 完成前后端动态配对，不依赖写死地址
- 使用 `Flutter + Riverpod` 实现跨平台客户端和状态管理
- 使用 `web_socket_channel` 支撑实时消息与 Agent 状态同步
- 使用 `flutter_secure_storage` 管理敏感连接信息与认证数据
- 通过 Actuator、诊断页和运行记录增强可观测性与问题定位能力

## 技术栈

| 分层 | 技术方案 |
| --- | --- |
| 后端 | Spring Boot 3.5、Spring Web、Spring WebSocket、Spring Validation、JDBC |
| 数据存储 | SQLite |
| 客户端 | Flutter、Dart 3、Riverpod |
| 通信 | HTTP API、WebSocket |
| 安全 | JWT、本地安全存储、请求限流、Host 收敛 |
| 部署 | 本地部署、Docker Compose、GraalVM Native Image |

## 仓库结构

```text
MicroFlow
├─ backend/              # Spring Boot 后端
├─ frontend/             # Flutter 跨平台客户端
├─ ops/                  # 运维与辅助脚本
├─ docker-compose.yml    # 本地部署编排
├─ DEPLOYMENT.md         # 部署文档
└─ README.md             # 项目说明
```

## 主要模块说明

### 1. 后端服务

负责认证、配对连接、工作区协作、消息处理和 Agent 运行支撑。

- 路径：`backend/`
- 技术关键词：`Spring Boot`、`WebSocket`、`SQLite`
- 主要能力：
  - Auth / JWT
  - Bootstrap Pairing
  - Workspace / Channels / Members
  - Message Service
  - Agent Run Service
  - Agent Diagnostics

### 2. Flutter 客户端

负责跨平台界面、连接建立、实时消息和本地配置保存。

- 路径：`frontend/`
- 技术关键词：`Flutter`、`Riverpod`、`web_socket_channel`
- 主要能力：
  - 首次连接页
  - 登录页与会话门禁
  - 工作区首页与频道列表
  - 消息面板与 Agent 面板
  - Agent runs / diagnostics 页面

### 3. 配对连接机制

用于解决前后端分离部署下的首次连接问题。

- 后端启动时生成一次性配对码
- 前端输入服务器地址和配对码完成握手
- 后端返回 `serverOrigin`、`apiBaseUrl`、`wsBaseUrl`
- 前端保存连接配置后进入登录流程

## 运行说明

### 环境准备

- JDK 21+
- Maven 3.9+
- Flutter 3+
- Docker（可选，用于本地编排）

### 启动后端

```powershell
cd backend
./mvnw spring-boot:run
```

默认地址：

```text
http://localhost:8080
```

健康检查：

```text
GET /api/v1/system/health
```

### 启动前端

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

开发阶段也可以显式指定地址：

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

- Agent provider 配置支持以下加载顺序：
  1. `MICROFLOW_AGENT_CONFIG_JSON`
  2. `MICROFLOW_AGENT_CONFIG_PATH`
  3. Spring 配置 `microflow.agent.providers`
  4. `OPENCLAW_ENDPOINT_URL` + `OPENCLAW_AGENT_KEYS`
  5. fallback `mock-openclaw`
- 是否生成演示账号由 `MICROFLOW_SEED_DEMO_ENABLED` 控制
- 推荐优先使用配对流程，而不是在前端写死服务地址

## 已完成的安全收敛

- 收紧配对访问逻辑与 Host 信任边界
- 限制 CORS 来源为本地或显式配置来源
- 为登录请求增加限流保护
- 对消息输入长度与列表上限进行校验
- 敏感信息迁移到安全存储
- 清理前端页面中的残留脏代码与默认回退逻辑

## 相关文档

- 部署文档：[DEPLOYMENT.md](DEPLOYMENT.md)
- 前端说明：[frontend/README.md](frontend/README.md)

