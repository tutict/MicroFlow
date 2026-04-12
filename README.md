# SoloFlow / MicroFlow

一个面向本地部署与内网协作场景的轻量级 AI 协作工作台。

SoloFlow 将传统团队沟通、实时消息和 AI Agent 能力整合到一个本地优先的系统中，目标不是做一个臃肿的平台，而是提供一套可以快速部署、快速展示、可继续扩展的协作底座。

## 项目一句话介绍

SoloFlow 是一个基于 Spring Boot + Flutter 构建的全栈协作系统，支持账号登录、工作区聊天、Agent 调用、实时通信、运行诊断，以及“前后端分离配对连接”的本地部署模式。

## 展示亮点

- 本地优先：适合开发机、实验室、内网环境或单机服务部署
- 前后端分离配对：前端首次启动不依赖写死地址，通过一次性配对码连接真实后端
- 实时协作：频道消息与 Agent 状态通过 WebSocket 实时更新
- Agent 集成：支持 Agent 列表、运行记录、角色策略和诊断页面
- 轻量存储：基于 SQLite，无需额外数据库即可跑通完整流程
- 安全收敛：已补齐登录限流、连接约束、消息输入边界和本地安全存储
- 跨平台客户端：Flutter 支持 Web、桌面和移动端

## 适合展示的项目价值

如果你要向老师、面试官、团队成员或评审介绍这个项目，可以把它理解为：

- 一个“本地版 AI 团队协作工作台”
- 一个“能聊天、能调用 Agent、还能看诊断的轻量协作系统”
- 一个“Spring Boot 后端 + Flutter 前端 + SQLite + WebSocket”的完整全栈样例
- 一个“适合继续扩展为企业内网工具或 AI 助手平台”的基础框架

## 核心场景

SoloFlow 适合以下展示场景：

1. 本地 AI 协作原型
2. 团队内部轻量沟通工具
3. 多 Agent 协作与调度实验平台
4. Spring Boot + Flutter 全栈课程项目
5. 可演示的本地部署型软件工程实践项目

## 系统架构

```text
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Frontend                        │
│                                                             │
│  - 配对连接页                                                │
│  - 登录页                                                    │
│  - 工作区首页                                                │
│  - 频道聊天                                                  │
│  - Agent 列表 / 运行记录 / 诊断页                            │
│                                                             │
│  HTTP API + WebSocket                                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                  Spring Boot Backend                        │
│                                                             │
│  - Auth / JWT                                               │
│  - Bootstrap Pairing                                        │
│  - Workspace / Channels / Members                           │
│  - Message Service                                          │
│  - Agent Run Service                                        │
│  - Agent Diagnostics                                        │
│  - Realtime Broadcaster                                     │
│                                                             │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ JDBC
                        │
                 ┌──────▼──────┐
                 │   SQLite    │
                 │             │
                 │ 用户 / 消息  │
                 │ 工作区 / 运行 │
                 └─────────────┘
```

## 技术选型

### Backend

- Java 21
- Spring Boot 3.5
- Spring MVC
- Spring WebSocket
- Spring Validation / JDBC
- SQLite
- GraalVM Native Image

### Frontend

- Flutter
- Dart 3
- Riverpod
- `http`
- `web_socket_channel`
- `flutter_secure_storage`

## 展示时建议这样讲

### 1. 先讲问题

很多协作系统依赖云端、部署复杂，而且 AI 工具往往只是外挂在聊天系统外面。

SoloFlow 想解决的是：

- 能不能做一个本地优先的协作系统
- 能不能把团队聊天和 AI Agent 能力放到一个统一工作台里
- 能不能让前端和后端分离部署，但连接过程依然简单安全

### 2. 再讲方案

这个项目的方案是：

- 后端负责认证、工作区、消息、Agent 执行与诊断
- 前端负责跨平台 UI、实时沟通和本地连接保存
- 首次连接采用一次性配对码，而不是写死服务器地址
- 数据用 SQLite 持久化，降低部署门槛

### 3. 最后讲亮点

- 能注册、登录、进入工作区
- 能实时收发消息
- 能 @Agent 触发执行
- 能查看 Agent 运行记录和诊断状态
- 能通过前端配对连接真实后端
- 能在本地或内网环境快速跑起来

## 核心功能

### 用户与工作区

- 注册 / 登录
- JWT 鉴权
- 默认工作区初始化
- 工作区成员与频道结构

### 实时消息

- 频道消息列表
- WebSocket 实时订阅
- 消息输入与发送
- 输入边界限制

### Agent 能力

- Agent 列表展示
- Agent 运行记录
- Agent 诊断页
- Agent 角色策略编辑
- 多 Agent 协作状态提示

### 配对连接

- 一次性 pairing code
- 前端首次连接页
- 后端返回运行时 API / WS 地址
- 支持前后端分离部署

## 业务流程

### 首次连接流程

1. 启动后端服务
2. 后端日志打印一次性配对码
3. 前端打开连接页
4. 用户输入服务器地址与配对码
5. 后端返回 `serverOrigin`、`apiBaseUrl`、`wsBaseUrl`
6. 前端保存连接配置并进入登录页

### 登录与使用流程

1. 用户登录
2. 进入工作区首页
3. 选择频道或会话
4. 发送消息或 `@agent`
5. 查看 Agent 响应、运行状态与诊断信息

## 建议演示脚本

如果你要现场展示，推荐按这个顺序：

### 第一部分：系统启动

1. 启动后端
2. 展示控制台中的 pairing code
3. 启动前端

### 第二部分：前端配对

1. 打开连接页
2. 输入服务器地址
3. 输入 pairing code
4. 完成握手后进入登录页

### 第三部分：工作区展示

1. 登录系统
2. 展示工作区首页布局
3. 展示频道、成员、Agent 面板

### 第四部分：Agent 展示

1. 在聊天里发送一条带 `@assistant` 的消息
2. 展示消息流和实时状态变化
3. 进入 Agent diagnostics 页面
4. 展示 provider、endpoint、认证状态、角色策略

### 第五部分：总结

1. 说明本地部署优势
2. 说明安全加固点
3. 说明未来扩展方向

## 快速开始

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

但当前更推荐使用配对流程，而不是依赖固定地址。

## 默认演示账号

如果启用了演示种子数据，可以使用：

- `demo@microflow.local`
- `demo12345`

注意：

- 演示账号不是永远存在
- 是否生成由 `MICROFLOW_SEED_DEMO_ENABLED` 控制

## 关键接口

- `POST /api/v1/bootstrap/pair`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/workspaces`
- `GET /api/v1/workspaces/{workspaceId}/channels`
- `GET /api/v1/channels/{channelId}/messages`
- `POST /api/v1/channels/{channelId}/messages`
- `GET /api/v1/agents?workspaceId=...`
- `GET /api/v1/agent-runs?workspaceId=...`
- `GET /api/v1/agent-diagnostics?workspaceId=...`

## Agent 配置

后端会按以下顺序加载本地 Agent provider 配置：

1. `MICROFLOW_AGENT_CONFIG_JSON`
2. `MICROFLOW_AGENT_CONFIG_PATH`
3. Spring 配置 `microflow.agent.providers`
4. `OPENCLAW_ENDPOINT_URL` + `OPENCLAW_AGENT_KEYS`
5. fallback `mock-openclaw`

示例：

```json
{
  "providers": [
    {
      "provider": "openclaw",
      "endpointUrl": "http://127.0.0.1:8787",
      "credential": "local-dev-token",
      "agentKeys": ["assistant", "reviewer"]
    }
  ]
}
```

## 已完成的安全与稳定性修正

- 后端配对访问逻辑已收紧
- 不再盲目信任请求 Host
- CORS 已限制为本地或显式可配置来源
- 登录请求增加限流保护
- 消息输入长度与列表上限已校验
- 前端不再默认回退到 `localhost`
- 前端敏感信息已迁移到安全存储
- 中文本地化资源与生成文件已修复
- Agent diagnostics 页面的残留脏代码已清理

## 为什么这个项目适合展示

- 它不是单纯的 CRUD，而是包含认证、实时通信、Agent、配对、安全和本地化的完整链路
- 它同时展示了后端架构能力和前端产品化能力
- 它可以讲“系统设计”，也可以讲“工程实现”
- 它既能本地跑通，也能扩展成更完整的平台

## 后续可扩展方向

- Docker / Docker Compose 一键部署
- 反向代理与 HTTPS 方案
- 多工作区管理
- 更复杂的 Agent 协作编排
- 文件上传与知识库接入
- 更完整的权限模型
- 移动端与桌面端专项优化

## 目录说明

```text
backend/    Spring Boot backend
frontend/   Flutter client
README.md   项目展示说明
```

## 相关文档

- 前端说明见 [frontend/README.md](/C:/Users/tutic/IdeaProjects/SoloFlow/frontend/README.md)
