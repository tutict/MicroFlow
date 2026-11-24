# MicroFlow Agent Harness 与前端协作工作台

来源：用户于 2026-11-23 提供的项目设计文档。以下为实现与验收依据；Provider 的实际能力仍以运行时检测为准。

## 目标

把聊天触发式 Agent 扩展为 MicroFlow 自有、可恢复、可审批的运行时 harness。保留 `@Agent` 和 `@team` 入口，并允许从任务启动 Agent；运行时负责上下文、步骤、工具权限、审批、产物和审计。前端沿用会话主画布，增强任务与运行状态的联动。

## Harness 与接口

- 一次 Agent 工作对应持久化的主运行，可关联任务、频道、触发消息和发起人。单 Agent 与 `@team` 协作作为运行步骤；保留轮数上限，不引入通用流程 DSL。
- 状态为 `QUEUED → CONTEXT_BUILDING → RUNNING → WAITING_APPROVAL → SUCCEEDED / FAILED / CANCELLED`。状态变化、工具调用写入追加式事件。重启恢复排队与待审批运行；进程中断的运行要求人工重试，避免重放外部动作。
- Context Builder 组合任务、项目、决策、活动、会话片段、知识库引用和按需连接器结果。展示实际来源；审计仅保存引用和必要摘要，不复制整个邮箱或文件库。
- Tool Registry 声明输入、权限和风险。读取、检索、内部草稿自动执行；修改任务、邮件、日历、WebDAV 写入先审批。拒绝无副作用，批准恢复原运行；SMTP 等结果不确定时禁止自动重试。
- Provider 使用结构化请求/响应循环，支持文本、工具调用、工具结果和完成状态。逐 Provider 检测工具能力，不支持时关闭工具调用，不把普通文本猜成动作。
- 首批连接器为 IMAP/SMTP、CalDAV、WebDAV，按需搜索/读取邮件、读取日历、列举/读取文件；外部写入与删除需审批。凭据默认私有，可明确共享给工作区、成员或 Agent。凭据加密、只写不读，不进行后台全量同步。
- 任务运行入口：`POST /api/v1/workspaces/{workspaceId}/tasks/{taskId}/agent-runs`。
- 运行查询：`GET /api/v1/workspaces/{workspaceId}/agent-runs`、`GET /api/v1/agent-runs/{runId}`、`/events`。
- 运行控制：`POST /api/v1/agent-runs/{runId}/approvals/{approvalId}/decision`、`/cancel`、`/retry`；`GET /artifacts`。
- 连接管理：`/workspaces/{workspaceId}/connectors`，包含探活与共享设置，密钥不回显。
- WebSocket 运行、审批、产物事件带每运行事件序号，断线按序号补拉。

## 前端

- 桌面会话为主画布；Inspector 为上下文 / 执行，展示任务、Agent 步骤、工具动作、审批与产物。
- 运行卡片展示排队、执行、待审批、失败与完成；审批说明动作、资源、影响、来源，并支持批准、拒绝和原因。
- “我的工作”按待处理、运行中、待审批、受阻、最近完成聚合。任务显示相关运行与产物，可启动 Agent；消息可转关联任务。角色管理移到工作区管理。
- 连接器设置展示状态、协议、授权、共享对象与可恢复错误；保存后不显示凭据。
- 桌面保留三栏，平板收起 Inspector，手机通过底部面板查看运行、来源和审批。
- Riverpod 独立更新运行、任务、审批；WebSocket 增量更新列表，避免每次进度刷新整个工作区。保留加载、空结果、断连、失败、重试、中英文、明暗主题、键盘和屏幕阅读器支持。

## 验收

- 后端测试覆盖状态转换、任务/消息关联、工作区隔离、角色、共享和能力检测。
- 集成验证未批准不写、拒绝无副作用、批准续跑、重启后审批有效、不确定外部动作不重复。
- Mock Provider 与本地协议服务验证连接器读取、审批写回、凭据加密、断连恢复。
- Flutter 测试覆盖运行卡片、审批、任务队列、连接器与桌面/手机布局；执行后端测试、`flutter analyze`、`flutter test`。
- 增量迁移保留既有记录；SQLite、本地运行、按需查询；首期采用自托管凭据或应用密码，不引入 OAuth、后台同步或通用工作流 DSL。
