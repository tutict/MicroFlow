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

### 任务推进（工作台核心）

会话解决「聊得到一起」，任务域解决「事情推得动」。两者构成个人与三三制小团队的完整工作面。

- **任务与项目分组**：任务支持项目归属、负责人、优先级、截止时间和显式状态机
- **我的工作聚合**：`GET /my-work` 跨项目汇总，按下一步动作分桶（可执行 / 受阻 / 待他人认领 / 近期完成）
- **决策留痕**：决策不可变，推翻是新增一条并指向被推翻的记录，「当初为什么这么定」始终可回溯
- **活动轨迹**：创建、改状态、指派、决策等动作留痕

### 任务与运行权限

工作区成员角色决定能力边界，而非仅作标签：

| 角色 | 分工 | 能力 |
| --- | --- | --- |
| OWNER | 决策者 | 全部，含角色管理 |
| MAINTAINER | 维护者 | 建项目、指派、推进任何任务 |
| OPERATOR | 执行者 | 建任务、推进与自己相关的任务 |
| VIEWER | 观察者 | 查看任务和运行；任务、项目、决策及连接器编辑/删除被拒绝 |

任务、项目、运行和连接器端点通过 `WorkspaceAccessGuard` 校验工作区成员与相应能力。
任务写入还要求维护权限或负责人/创建者关系；Agent 审批检查实际目标和批准者，执行前再校验。
发起人可停止自己已经启动的运行；连接探活检查成员及共享范围。
工作区始终保留至少一名所有者，最后一名所有者不可被降级。

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
- Android / iOS 客户端可扫描二维码，确认设备后完成握手
- 桌面与 Web 客户端保留服务器地址和配对码手动输入方式
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
配对控制台：http://127.0.0.1:8080/api/v1/bootstrap/console
```

常用参数：

```powershell
.\scripts\start-debug-preview.ps1 -BackendPort 8081 -FrontendPort 3001
.\scripts\start-debug-preview.ps1 -SeedDemo
.\scripts\start-debug-preview.ps1 -NoBrowser
.\scripts\start-debug-preview.ps1 -SkipPubGet
```

手机扫码配对时，将 `HostName` 设置为手机可访问的局域网地址，然后在电脑浏览器打开脚本输出的配对控制台：

```powershell
.\scripts\start-debug-preview.ps1 -HostName 192.168.1.20
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
.\mvnw.cmd quarkus:dev
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
- Agent Harness 与工作台设计：[docs/agent-harness-workbench.md](docs/agent-harness-workbench.md)
- 运行时与工作台优化记录：[docs/runtime-workbench-progress.md](docs/runtime-workbench-progress.md)

