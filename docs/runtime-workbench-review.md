# 完整提交候选四轴审阅与处置

2026-11-24，用户授权“四轴 review 校验，没问题后提交并推送”。基线为 `e7e25c734bb7d72b1c5cea4699f33c9db8650888`，审阅包含任务、角色、运行时、连接器基础代码和工作台增量的完整 264 文件候选：168 后端、87 前端、4 文档、3 脚本及 README/.gitignore。范围和 SHA-256 由 `.codex-tmp/harness-next-step/commit-candidate.json` 保存。个人记忆、缓存、DB、密钥和渲染产物不进入提交。

独立后端/前端首轮审阅识别 12 项后端与 5 项前端 Important；后续发现打包运行类型缺失、工具调用身份冲突、角色更新竞态，以及重复启动和创建任务，共 22 项 Important。根负责人按实际失败证据修复，并完成最新全量验证；最终各轴由独立后端/前端审阅者确认，旧增量审阅不能代表完整候选通过。

## 完整候选处置

| 关注面 | 修复与证据 |
| --- | --- |
| 恢复与执行 | 超过 200 条完整分页；APPROVED 外部调用在崩溃恢复后变 UNKNOWN；重试/调用原子条件。取消先胜出则零动作；动作已开始再取消，保留真实 SUCCEEDED/UNKNOWN 结算且运行仍 CANCELLED，不自动重发。 |
| 权限 | 审批实际目标/实际批准者及审计；VIEWER 的既有任务/连接器写入拒绝；工作区外探活零连接。所有角色更新用同一 SQL 检查当前 actor OWNER、目标预期角色与至少一个 OWNER；过期请求返回 409/403 且不写入。 |
| 协议与凭据 | UTC 日历与稳定审批 UID；接收 PUT 后断连变 UNKNOWN 并拒绝重试；可信错误 SAN 在两种 TLS/邮件协议中认证前失败；凭据单字段补丁及不回显。 |
| 工作台 | A→B→A 角色与任务范围守卫，过滤请求乱序、队列错误/重试/去重，真实 home 手机/平板任务入口。同一工作区/任务共用未完成启动请求；菜单显示等待和错误；任务创建防 Enter+点击重复提交，编辑代次保护新草稿。 |
| 来源与 Provider | 最新三条决策/五条活动、原历史 ASC 兼容、知识单次检索引用；真正 probe、工具方向/目录、24h 缓存边界。Legacy 与 Mock 缺省调用 ID 在持久化前唯一分配；现代缺空/批次和跨轮重复 ID 拒绝，跨 attempt 不把不同函数或输入关联到旧结果，持久化重复 ID 安全失败。 |
| 迁移与运行包 | 目录/JAR 清单、缺失/漏注册与旧数据/方向列回归；项目私有 JDBC 和 KnowledgeUpload 边界 DTO 移除不支持的 Spring 运行类型，两项完整 Spring 库仅用于测试。未改原 SQL/事务边界，未增依赖或版本；真实生产 JAR 的注册、工作区和知识上传已通过。 |
| 开发启动 | 强随机持久化密钥、隔离 DB、Hidden helper、端口/LAN/Android 前缀及既有后端保留；PowerShell 7/5.1 各 18 项通过。 |

首轮后端 RED 为 135 项中 15 failures/9 errors；授权/凭据 RED 为 150 项中 14 failures；来源/Provider RED 为 44 项中 35 failures；最终持久化请求 RED 为 59 项中 6 failures。前端首轮 14 个失败修复后相关 60 项通过；补充组有一项重复写缺陷和一项测试夹具动画超时，分别修复产品与夹具。日历 UID 初次回归被 UTC 异常挡住，后续以同审批跨实例目标一致及不同审批分离验证，未伪称独立 UID RED。

## 最终验证与四轴结论

| 轴 | 最终状态 | 独立确认依据 |
| --- | --- | --- |
| Spec | PASS | 本次增量及兼容契约具备实现/回归；明确原文后续范围。 |
| Standards | PASS | Quarkus、SQLite、Riverpod、本地化；无新增依赖或生产数据动作；提交清单与授权匹配。 |
| Implementation Quality | PASS | 22 项已确认 Important 全部修复和回归；角色、调用身份、未知结果和私有 JDBC 路径复查。 |
| Verification & Evidence | PASS | 最新后端 239、前端 156、分析、五组渲染、脚本双版本、package 与真实 JVM 全部通过；以实际日志和冻结来源判断。 |

修复后独立后端 revision 2、前端 revision 3 均给出四轴 PASS，无未处置 Important。两席分别直接核对代码、实际日志、候选哈希和最终文档；前端另逐张检查五组渲染。

| 最新检查 | 已观察结果 |
| --- | --- |
| 后端 `mvn -o test` | 239 项，0 failures、0 errors、0 skipped |
| `mvn -o -DskipTests package` | BUILD SUCCESS |
| 实际 `java -jar target/quarkus-app/quarkus-run.jar` | prod/loopback/隔离 DB：health、bootstrap 地址、注册、工作区写入、知识 multipart 上传/列表和环境恢复全部 PASS |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 156 项通过 |
| 原生 Flutter 渲染 | 5 组通过，桌面/手机、中英文、明暗主题、1.8 倍文字缩放；独立审阅者逐张查看 |
| 手机开发脚本 | PowerShell 7 与 Windows PowerShell 5.1 各 18 项通过 |

实际日志和修复后独立报告保存在 `.codex-tmp/harness-next-step/`。264 个暂存文件与清单完全一致，Git 规范化 blob 和工作树 SHA-256 均无差异，`git diff --cached --check` 通过。测试后仅清理接口文件末尾一行空白，已证明正文完全一致；最终文档结论更新后再次核对暂存清单。不以 Worker 自报或此前通过结果替代实际观察。

后续定向 RED 为工具身份 37/9 failures、Mock 身份 4/1 failure、角色原子更新 5/4 failures，以及持久化/Mock 身份 29/2 failures；最终后端定向 64 项全部通过。前端重复提交/草稿组 RED 43 pass/12 failures，GREEN 55；13 个新增回归均包含在最终 156 中。RED 的一个 timeout 是失败断言后未完成请求造成的级联，不另称独立产品缺陷。

全量验证另保留两个环境/夹具失败：上传测试漏记客户端附加的 charset，修正为显式发送并完全比对同一 MIME 类型；smoke 用 null 恢复环境时留下空变量，改为显式删除不存在的变量并检查恢复。后者导致的一轮 16 errors/93 skipped 未作通过证据；最新独立进程的 239 项和修正后 smoke 均已通过。

## 2026-11-23 增量审阅归档

当时范围由 `changed-files.json`、`scoped.diff` 和快照确定，仅覆盖增量，排除了既有未提交基础工作。首个审阅服务临时繁忙，改用另一可用审阅者完成。

## 重要问题与验证

| 问题 | 处置 | 回归证据 |
| --- | --- | --- |
| 补拉推进序号却未应用最新快照 | 应用恢复记录的最新运行快照及资源失效，再消费该记录序号 | `history catch-up applies a newer snapshot before suppressing its socket event`，失败到通过 |
| 刷新失败回滚实时进度 | 使用当前缓存，忽略已被更新请求替代的失败 | `failed refresh preserves a newer live snapshot`、`an older failed request cannot replace the result of a newer refresh`，失败到通过 |
| 默认运行窗口丢失任务覆盖 | 活跃运行分页补齐，任务历史独立缓存并合并，手动刷新更新历史 | `more than fifty pending runs cannot hide a task approval badge`、`task history remains available outside the workspace window`、`manual refresh reloads task history outside the workspace window`，失败到通过 |

后端 `activeRunPagingCoversMoreThanTheDefaultWindowWithoutRepeatingRows` 验证活跃页不重复、不遗漏，也经历失败到通过。

当时修复后由执行者检查实现与观察证据：

- Spec：本轮的审批恢复、队列、实时合并、详情与管理入口具备实现和对应验证；后续原文范围单独记录。
- Standards：遵循现有 Quarkus/JDBC、Flutter/Riverpod 结构及本地化资源，不新增依赖，保留原有工作。
- Implementation Quality：重要发现已修复，使用公开 Riverpod 接口；当时保留角色往返竞态。
- Verification & Evidence：后端 100 项、前端 119 项、静态分析和五组渲染检查通过。独立审阅未在修复后再跑一轮；修复以回归测试和全量结果验证。

## 角色往返竞态后续处置

2026-11-24 请求代次守卫已覆盖 A→B→A 的旧成功、AppException、意外异常应答，三个新增回归先失败后通过，修复后角色文件九项通过。旧应答不再覆盖新的显示角色、等待状态和共享壳回调；不再列为待办。

## 审阅边界

聊天入口统一、更多连接器读取/删除、启动前预览、动态连接器结果完整来源记录及完整任务详情为后续增量。真实外部 Provider/账户、真机、专门键盘/屏幕阅读器及 GraalVM 二进制未验证；本地 Mock/协议、原生 widget 渲染与 JVM 临时进程只证明其各自边界。生产部署和用户生产数据库未操作。
