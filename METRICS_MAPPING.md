# Metrics & Privacy Mapping (指标与隐私映射)

本文档把《design_all_phases_integrated.md》15.1 的漏斗指标，映射到 Interfit 内部可记录的“事件”（event）与最小字段（properties）。

目标：
- 指标可计算、口径可复现、字段不踩隐私红线。
- 事件命名稳定（版本化），用于后续埋点实现与回归验收。

## 1. 全局约定

### 1.1 事件结构（建议）

- `name`: `snake.case` / `dot.case`（示例：`app.first_open`、`workout.started`）
- `ts`: ISO8601 或 epoch seconds
- `user_opt_in`: `Bool`（是否允许匿名使用数据；为 false 时不上传/不落盘 analytics）
- `session_id`: UUID（训练会话级）
- `plan_id`: UUID（计划级，可为空：如 QuickStart）
- `properties`: `[String: String]`（仅允许白名单字段）

### 1.2 隐私红线（强制）

- 不采集歌曲名、歌手名、专辑名、播放列表名、评论文本、帖子正文、用户昵称等内容型数据。
- 仅采集“来源类型/是否可用/是否降级/错误原因”等状态位与枚举值（可解释、不可逆推具体内容）。
- 提供“允许匿名使用数据”开关；关闭后不再产生 analytics 事件（本地训练/计划/历史不受影响）。

## 2. 事件字典（最小集合）

### 2.1 生命周期

- `app.first_open`：首次启动（仅触发一次）
- `app.open`：每次启动

### 2.2 权限/可用性（示例：音乐、通知）

- `permission.prompt_shown`（properties：`kind`）
- `permission.result`（properties：`kind`, `result`=`granted|denied|restricted|notDetermined`）
- `capability.status`（properties：`kind`, `usable`=`true|false`, `reason`=枚举）

### 2.3 计划/复用

- `plan.created`
- `plan.edited`
- `plan.published`
- `plan.saved_to_library`（从社区/模板保存）
- `plan.applied`（从社区/模板 apply 进入训练）
- `plan.apply_blocked_duplicate`（重复 apply 被阻止）

### 2.4 训练

- `workout.started`（properties：`entry`=`quick_start|plan|template|community_apply`）
- `workout.paused`（properties：`reason`=枚举）
- `workout.resumed`（properties：`reason`=枚举）
- `workout.completed`（完成所有组）
- `workout.ended`（提前结束）
- `workout.interruption`（properties：`kind`=枚举, `reason`=枚举）
- `workout.recovery_prompt_shown`
- `workout.recovery_decision`（properties：`decision`=`continue|end_save|discard`）
- `workout.degraded`（properties：`source`=枚举, `reason`=枚举, `action`=枚举）

### 2.5 社区与质量

- `post.view`（properties：`post_type`=`free|paid`）
- `post.apply`（对帖子点击 apply）
- `post.report`（properties：`reason`=枚举）

## 3. 指标 → 事件映射（15.1）

> 记号：`U` 表示用户（或匿名安装实例）；`T0` 表示首次启动时间。

### 3.1 首启 → 开练

- `time_to_first_workout_started`
  - 口径：`min(ts(workout.started) - ts(app.first_open))`（同一 U）
  - 依赖事件：`app.first_open`, `workout.started`
- `first_session_start_rate`
  - 口径：`count(U with workout.started) / count(U with app.first_open)`
- `no_permission_start_rate`
  - 口径：在出现 `permission.result(kind=music, result!=granted)` 后仍 `workout.started` 的占比（分 `entry`）

### 3.2 开练 → 完成

- `first_session_complete_rate`
  - 口径：首个 `workout.started` 对应 session 是否出现 `workout.completed`
- `interruption_recovery_rate`
  - 口径：发生 `workout.interruption` 的 session 中，出现 `workout.resumed`（或 `workout.recovery_decision=continue`）的占比

### 3.3 次日回访

- `d1_return_rate`
  - 口径：`app.open` 发生在 `T0+24h` 到 `T0+48h` 的 U 占比

### 3.4 复用

- `plan_reuse_rate`
  - 口径：`workout.started(entry=plan)` 中，`plan_id` 在过去 N 天已被用于训练 ≥2 次的占比
- `library_save_rate`
  - 口径：`plan.saved_to_library / post.view`（或 / `plan.applied`，需固定版本口径）
- `duplicate_apply_block_rate`
  - 口径：`plan.apply_blocked_duplicate / plan.applied_attempted`（若无 attempted 事件，可先用 `plan.apply_blocked_duplicate / plan.applied` 近似，后续补齐）

### 3.5 分享与质量（最小）

- `plan_publish_rate`
  - 口径：`plan.published / plan.edited_or_created`（需明确分母：创建用户 or 编辑次数）
- `post_apply_rate`
  - 口径：`post.apply / post.view`
- `report_rate`
  - 口径：`post.report / post.view`

### 3.6 市场转化（占位）

此部分依赖 Phase2+ 付费实现，事件先占位：
- `purchase.started`, `purchase.succeeded`, `purchase.failed`, `subscription.status_changed`

## 4. 验收口径（用于 3.6.1/3.6.2）

### 4.1 3.6.1（文档）

- 本文件存在并覆盖 15.1 中列出的指标，且每个指标都有：
  - 明确分子/分母或计算公式
  - 依赖事件列表
  - 至少一个关键字段说明（如 `entry`/`reason`）

### 4.2 3.6.2（隐私回归）

- 事件白名单字段中不包含任何歌曲名/评论文本等内容字段。
- “允许匿名使用数据”关闭后：
  - 不产生/不上传 analytics 事件（可通过本地日志或 debug report 验证）
  - 训练/计划/历史功能不受影响

