# 微澜协作

**微澜协作（MicroFlow）** 是一个面向本地部署与内网协作场景的轻量级 AI 协作工作台。项目面向一人公司、三三制小团队和私有化协作场景，整合工作区会话、任务推进、Agent 执行、知识库、基础会计和前后端配对连接。桌面与手机分别采用适配的导航和操作布局，支持中文、英文及明暗主题。

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
- 任务与项目分组、按行动聚合的“我的工作”、决策和活动留痕
- Agent 列表、运行记录、角色策略和诊断信息展示
- 任务绑定的 Agent 执行、步骤与事件追踪、审批、取消和重试
- 工作区连接器管理与连接探测
- 知识库资料上传、检索和协作上下文沉淀
- 基础会计模块，覆盖科目、凭证和试算平衡等场景
- 前后端分离场景下的一次性 Pairing Code / 二维码配对连接
- 基于 SQLite 的轻量级本地持久化
- 一键启动本地 debug 预览环境

### 工作台与输入体验

- **桌面导航**：主导航带文字，会话列表支持对已加载标题与摘要进行本地筛选，任务页面使用完整工作面。
- **手机导航**：底栏直接进入会话、我的工作、知识库和工具；任务分组使用选择菜单，偏好设置按组展示。
- **消息输入**：正文使用完整宽度，提及和团队协作模式放在工具栏；空白文本和发送中的重复提交受保护。
- **页面内草稿**：按用户、工作区和会话隔离，切换模块后恢复，发送失败时保留。
- **连接恢复**：配对、切换或移除设备失败后恢复可用状态，请求期间保留连接表单。

| 操作 | 快捷键 |
| --- | --- |
| 定位会话筛选 | Ctrl / ⌘ + K |
| 发送消息 | Ctrl / ⌘ + Enter |
| 输入换行 | Enter |

快捷发送会检查输入法组词状态。设计参照、具体行为和适配验证见 [前端体验记录](docs/frontend-experience.md)。

### 任务推进（工作台核心）

会话解决「聊得到一起」，任务域解决「事情推得动」。两者构成个人与三三制小团队的完整工作面。

- **任务与项目分组**：任务支持项目归属、负责人、优先级、截止时间和显式状态机
- **我的工作聚合**：`GET /api/v1/workspaces/{workspaceId}/my-work` 在工作区内跨项目汇总，按下一步动作分桶（可执行 / 受阻 / 待他人认领 / 近期完成）
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

### Agent 执行与连接器

Agent 运行与任务关联，可查看步骤、事件、上下文来源、审批和产物。需要审批的操作通过运行详情处理；发起人可取消运行，符合权限的用户可重试。连接器按工作区管理并提供探测入口，编辑和执行受工作区角色及共享范围约束。

运行时结构与接口说明见 [Agent Harness 与工作台设计](docs/agent-harness-workbench.md)。

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
| 后端 | Java 21、Quarkus 4.0.1、Jackson 3.1.8、RESTEasy、WebSocket、Hibernate Validator |
| 数据存储 | SQLite，JDBC 驱动 3.54.1.0 |
| 客户端 | Flutter 3.47+ / Dart 3.13+、Material UI、Cupertino UI、Riverpod 3.5.0、FlexColorScheme 9.0.0 |
| 构建链 | Maven wrapper 3.10.2；Gradle 9.9.2、AGP 9.5.3、Kotlin 2.4.21 |
| 通信 | HTTP API、WebSocket |
| 安全 | JWT、WebSocket Ticket、登录限流、Host/CORS 校验、AES-GCM 消息加密 |
| 部署 | 本地启动、Docker Compose、GraalVM Native Image |

## 仓库结构

```text
MicroFlow
├─ backend/                         # Quarkus 后端服务
├─ frontend/                        # Flutter 跨平台客户端
├─ docs/                            # 设计、迁移、验证与独立审阅记录
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
- 主要能力：Auth / JWT、Bootstrap Pairing、Workspace / Channels / Members、Message Service、Tasks / My Work / Decisions、Agent Runtime、Connectors、Knowledge Base、Accounting

### Flutter 客户端

客户端负责跨平台界面、连接建立、实时消息、本地连接配置和业务页面展示。

- 路径：`frontend/`
- 技术关键词：`Flutter`、`Riverpod`、`web_socket_channel`
- 主要能力：首次连接与会话门禁、适配导航、会话筛选与草稿、我的工作、任务工作台、运行与审批详情、连接器设置、知识库和会计页面

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

- JDK 21，并将 `JAVA_HOME` 指向该安装；最近使用 JDK 21.0.8 验证。
- Flutter 3.47+ / Dart 3.13+；最近使用 Flutter 3.47.5 / Dart 3.13.4 验证。
- Maven 由 `backend/mvnw` 或 `backend/mvnw.cmd` 下载并运行，固定为 3.10.2；无需单独安装全局 Maven。
- Android SDK（构建 APK 时需要）；NDK 版本跟随 Flutter SDK，最近验证使用 28.2.13676358。
- Docker（可选，用于本地编排）

依赖升级版本、迁移说明和验证结果见 [依赖升级记录](docs/dependency-upgrade.md)。

### 一键 debug 预览

从项目根目录运行。先将项目 wrapper 加入当前 PowerShell 的工具搜索路径，并配置开发页面的明确 HTTP 来源：

```powershell
$microFlowBackend = (Resolve-Path .\backend).Path
$env:Path = "$microFlowBackend;$env:Path"
$env:MICROFLOW_HTTP_ALLOWED_ORIGIN_PATTERNS = 'http://localhost:3000,http://127.0.0.1:3000'
.\scripts\start-debug-preview.ps1
```

脚本会优先从 `PATH` 查找 `mvnw.cmd`。在工具路径准备好后，也可使用包装脚本：

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

更换预览端口时同步设置允许的 HTTP 来源：

```powershell
$env:MICROFLOW_HTTP_ALLOWED_ORIGIN_PATTERNS = 'http://localhost:3001,http://127.0.0.1:3001'
.\scripts\start-debug-preview.ps1 -BackendPort 8081 -FrontendPort 3001
```

其他可选参数：`-SeedDemo` 生成演示账号，`-SkipPubGet` 跳过依赖解析，`-Hidden` 隐藏辅助终端，`-StrictSecrets` 要求配置正式密钥。`-NoBrowser` 跳过脚本额外打开预览 URL；Flutter Chrome 仍会创建调试窗口。

手机访问后端时，让电脑与手机处于可互访的局域网，并配置后端监听地址及用于生成连接信息的主机地址：

```powershell
$env:QUARKUS_HTTP_HOST = '0.0.0.0'
.\scripts\start-debug-preview.ps1 -HostName 192.168.1.20 -NoBrowser
```

电脑浏览器通过 `http://127.0.0.1:8080/api/v1/bootstrap/console` 获取配对码或二维码，手机客户端连接局域网地址。Flutter Chrome 页面在电脑本机调试。

默认参数下，脚本会为前端注入：

```text
MICROFLOW_API_BASE_URL=http://127.0.0.1:8080/api/v1
MICROFLOW_WS_BASE_URL=ws://127.0.0.1:8080/ws
```

脚本日志默认写入：

```text
.codex-tmp/debug-preview/
```

一键脚本的数据库位于项目根目录 `microflow.db`；手动后端启动默认使用 `backend/microflow.db`，可通过 `MICROFLOW_DB_PATH` 指定数据位置。

### 手动启动后端（本地开发）

```powershell
cd backend
$env:MICROFLOW_ALLOW_INSECURE_DEFAULT_SECRETS = 'true'
$env:MICROFLOW_HTTP_ALLOWED_ORIGIN_PATTERNS = 'http://localhost:3000,http://127.0.0.1:3000'
.\mvnw.cmd quarkus:dev
```

以上默认密钥开关仅用于本地开发。正式部署应配置 JWT 和消息加密密钥。macOS / Linux 可使用 `./mvnw`。

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
flutter run -d chrome --web-port 3000
```

开发阶段也可以显式指定后端地址：

```powershell
flutter run -d chrome --web-port 3000 `
  --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 `
  --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws
```

## 校验与构建

后端使用配置的 Maven wrapper 完成测试和打包：

```powershell
cd backend
.\mvnw.cmd clean verify
```

前端解析锁文件后运行测试、分析及所需平台的构建：

```powershell
cd frontend
flutter pub get
flutter test
flutter analyze
flutter build web --release
flutter build web --wasm --release --output=build/web-wasm
flutter build apk --debug
```

Web 产物位于 `frontend/build/web/`，Wasm 位于 `frontend/build/web-wasm/`，调试 APK 位于 `frontend/build/app/outputs/flutter-apk/app-debug.apk`。Android 构建所需组件和迁移约束见 [依赖升级记录](docs/dependency-upgrade.md)。

最近完整验证记录（2026-11-26）：

| 检查 | 结果 |
| --- | --- |
| 前端测试与分析 | 203 项测试通过，分析无问题 |
| Java 21 后端验证 | 241 项测试通过，打包成功 |
| 平台构建 | Web、实际 Wasm、Android 调试 APK 成功 |
| 原生 Flutter 渲染 | 15 个桌面、平板、手机、双语、明暗主题及大字体场景通过 |
| 浏览器主路径 | 配对登录、刷新恢复、筛选、草稿与发送、任务创建、手机导航及偏好切换通过 |
| 独立四轴审阅 | 规格、规范、实现质量、验证证据在已声明范围内通过 |

真机摄像头、旧密钥库迁移、系统文件对话框、iOS/macOS 构建、Docker 镜像运行、真实读屏软件及多线程 Wasm 性能尚未验证。接受范围和证据见 [四轴审阅报告](docs/reviews/2026-11-26-four-axis-review.md)。

## 关键接口

基础协作与部署诊断：

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

任务与项目：

- `GET /api/v1/workspaces/{workspaceId}/task-projects`
- `POST /api/v1/workspaces/{workspaceId}/tasks`
- `GET /api/v1/workspaces/{workspaceId}/my-work`
- `GET /api/v1/workspaces/{workspaceId}/tasks/{taskId}/decisions`
- `POST /api/v1/workspaces/{workspaceId}/tasks/{taskId}/decisions`

任务绑定的 Agent 运行：

- `POST /api/v1/workspaces/{workspaceId}/tasks/{taskId}/agent-runs`
- `GET /api/v1/workspaces/{workspaceId}/agent-runs`
- `GET /api/v1/agent-runs/{runId}/events`
- `POST /api/v1/agent-runs/{runId}/approvals/{approvalId}/decision`
- `POST /api/v1/agent-runs/{runId}/cancel`
- `POST /api/v1/agent-runs/{runId}/retry`

## 配置说明

- Agent provider 配置支持以下加载顺序：`MICROFLOW_AGENT_CONFIG_JSON`、`MICROFLOW_AGENT_CONFIG_PATH`、Quarkus 配置 `microflow.agent.openclaw-*`、`OPENCLAW_ENDPOINT_URL` + `OPENCLAW_AGENT_KEYS`、fallback `mock-openclaw`
- 是否生成演示账号由 `MICROFLOW_SEED_DEMO_ENABLED` 控制。
- 本地 debug 预览脚本默认启用 `MICROFLOW_ALLOW_INSECURE_DEFAULT_SECRETS=true`，仅用于开发环境。
- 生产或正式部署应显式配置 `microflow.jwt.secret` 和 `microflow.crypto.secret`。
- HTTP 来源通过 `MICROFLOW_HTTP_ALLOWED_ORIGIN_PATTERNS` 配置；来源应匹配浏览器页面的协议、主机与端口。
- 安全存储保留 10.3.4 的旧数据迁移路径；升级 11.x 前需确认现有安装完成迁移，详见依赖升级记录。
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
- **桌面与手机适配**：文字导航和手机底栏、会话筛选、快捷输入与页面内草稿共同支持高频协作。
- **可观测性友好**：健康检查、诊断页、Agent 运行记录和脚本日志便于定位问题。
- **部署路径完整**：支持本地开发、Docker Compose 和后续 Native Image 扩展。

## 相关文档

- 部署文档：[DEPLOYMENT.md](DEPLOYMENT.md)
- 前端说明：[frontend/README.md](frontend/README.md)
- 前端体验与产品参照：[docs/frontend-experience.md](docs/frontend-experience.md)
- 依赖升级、迁移与构建记录：[docs/dependency-upgrade.md](docs/dependency-upgrade.md)
- 独立四轴审阅：[docs/reviews/2026-11-26-four-axis-review.md](docs/reviews/2026-11-26-four-axis-review.md)
- Agent Harness 与工作台设计：[docs/agent-harness-workbench.md](docs/agent-harness-workbench.md)
- 运行时与工作台优化记录：[docs/runtime-workbench-progress.md](docs/runtime-workbench-progress.md)

