# 运行时与工作台联动 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement the tasks in order; use a fresh reviewer for the final scoped change review.

**Goal:** 补齐现有运行时的审批续跑、执行可见性，以及“我的工作”和单运行实时状态的联动。

**Architecture:** 保持 Quarkus/SQLite 与 Flutter/Riverpod，单负责人顺序实现。任务分桶由服务端决定；运行列表共享工作区缓存，事件只合并相关运行，缺口按序号补拉。现有未提交工作为基线，所有改动在当前工作区中追加。

**Tech Stack:** Java 21、Quarkus 3.35.4、SQLite、Dart、Flutter、Riverpod 3。

**Spec:** [Agent Harness 与工作台设计](../../agent-harness-workbench.md)

## Global Constraints

- 保留既有任务字段、四个分桶及其语义，新增运行中和待审批分桶，客户端不重算归属。
- 不引入 OAuth、后台全量同步、流程 DSL 或新依赖；不修改生产数据库。2026-11-24 用户已明确授权四轴 review 通过后提交并推送，覆盖此前禁止提交的历史约束。
- 未批准的写操作不执行，不确定外部动作不可重试；已有运行/事件/步骤记录保留。
- 保留中英文、明暗主题、桌面/手机布局；状态与恢复操作可见。
- 使用 Lightweight：一个实现负责人，无并行写入需求；兼容性、持久化恢复、权限和 UI 都需验证。

## Review Focus

- 同一模型响应包含多个工具动作，审批/拒绝后不能丢失剩余动作或重复执行已完成动作。
- 重复、乱序、缺失的 WebSocket 事件不能回退状态或触发工作区整体重取。
- 切换工作区/任务时，缓存、异步请求、事件补拉和轮询必须留在正确作用域。
- 待审批任务不能因默认运行列表的窗口被遗漏，旧客户端仍能读取旧分桶。
- 观察者没有角色修改能力；手机、大字号、中英文下审批和恢复操作可达。

## Tasks

### Task 1: 审批续跑与执行审计

Files: `AgentRuntimeService.java`、`JdbcAgentRuntimeRepository.java`、新增运行时集成测试。

- [x] 用一批“审批写入 → 草稿 → 再次审批”的调用复现批准/拒绝后丢失动作。
- [x] `mvn -o test` 观察新增断言失败。
- [x] 从本次上下文之后的持久化对话恢复未回应的工具调用；记录每次模型调用步骤，保持轮数限制。
- [x] 事件附带已持久化的运行快照；运行查询优先显示待审批/活跃运行。
- [x] 验证审批前不写、逐次审批、拒绝无写入、事件与步骤、未知结果不重试。

### Task 2: 服务端任务队列

Files: 任务服务、任务 DTO/mapper、运行状态查询适配器与 API 测试。

- [x] 覆盖运行中、待审批、多个活跃运行优先级和工作区隔离的失败测试。
- [x] 新增任务侧运行状态查询接口；只查询当前任务集合并由服务端分桶。
- [x] 保留既有任务归属和完成记录；验证队列互斥、数量、状态变更与权限。

### Task 3: 按运行更新与按序号恢复

Files: 运行时 providers、任务 queue providers、壳控制器、执行面板及 provider 测试。

- [x] 覆盖单运行更新不重取列表、重复/乱序忽略、缺口分页、断线恢复和作用域切换。
- [x] 共享工作区运行列表，按任务派生索引；事件快照增量合并，兼容旧事件的单运行查询。
- [x] 活跃运行在断连时保留局部轮询，联网时依靠事件；执行面板随查询参数更新。
- [x] 只刷新受影响的任务队列、审批、步骤、来源与产物；验证请求范围和恢复失败路径。

### Task 4: 工作台与管理界面

Files: 我的工作实体/DTO/页面、运行详情与步骤、工作区管理入口、l10n、widget 测试。

- [x] 新增运行中/待审批队列与执行详情交互的失败测试。
- [x] 展示步骤、来源、审批和产物；详情支持取消、重试和审批。
- [x] 把角色管理从任务页移到工作区管理；角色更新同步当前成员状态。
- [x] 验证中英文、明暗主题、手机/桌面、加载/空/错误/重试和可访问状态。

### Final verification

- [x] 后端 `mvn -o test`。
- [x] 前端 `flutter analyze`、`flutter test`。
- [x] 渲染检查桌面与手机，审阅相对于本轮基线的实际改动。
- [x] 更新本文件完成状态与 `docs/runtime-workbench-progress.md`，记录验证与后续文档差距。

## Scope after this increment

聊天 `@Agent` / `@team` 主运行迁移、更多连接器读取/删除工具和启动前上下文预览仍属于原文的后续增量；本轮不把它们标记为完成。

## Verification results

2026-11-23 归档：后端 100 项、前端 119 项、分析及五组原生渲染通过。2026-11-24 对完整提交候选扩大四轴审阅，角色 A→B→A 已以三个红绿回归修复；新增恢复、权限、协议、来源、Provider、移动入口和生产 JDBC 兼容修复及最新验证见 docs/runtime-workbench-review.md。整个原文愿景仍按后续增量推进。
