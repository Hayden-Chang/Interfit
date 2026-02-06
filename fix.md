# Workflow State (工作流状态)

## 🎯 Current Objective (当前宏大目标)

- [x]  修复《Interfit》 IOS应用的特性修改和问题修复。
- [x]  技术栈：IOS

## 🔄 Phase & Status (当前阶段与状态)

- **Current Phase**: 2.0 (Done)
- **Last Action**: Completed 2.3 + cleanup: removed a potential AudioSessionManager deadlock and added regression test; removed user-specific `DEVELOPMENT_TEAM` from project while keeping Apple Music usage description.
- **Next Step**: Done

## 📝 Task List (任务清单)

    - [x]  1.1 在train页面，选择自定义的plan，无法点击开始
    - [x]  1.2 第一次进入，选中一个preset的plan后，点击start后不会开始，出来，再点击start才会开始
    - [x]  1.3 在真机中，无法打开apple music。选择了add music，open settings，里面没有apple music选项
    - [x]  1.4 实现my playlist
    - [x]  1.5 选择音乐应该在创建计划的时候时候就选择好了，训练的时候是直接播放的。 有两种选择模式：（1）只需要选择两个音乐：work音乐和reset音乐；（2）为每个work选择一个音乐，reset只需要选择一个音乐。先进行详细，拆解任务，然后逐条实现
        - [x] 1.5.1 数据模型：Plan/PlanSnapshot/PlanVersion 增加 musicStrategy（含迁移/兼容）+ 单测
        - [x] 1.5.2 计划编辑：新增 Music 设置 UI（模式切换 + Work/Rest 选择；按 Set 选择）
        - [x] 1.5.3 训练播放：Training 启动时按策略自动选择并播放（Work/Rest 切换）
        - [x] 1.5.4 回归：Shared 单测 + iOS build 通过
    - [x]  1.6 点击end后卡死
        - [x] 1.6.1 定位原因：确认卡死路径与触发条件
        - [x] 1.6.2 修复：End 后始终能进入 Summary（含 recovery/plan=nil 场景）
        - [x] 1.6.3 单测：为修复点补充覆盖
        - [x] 1.6.4 回归：`swift test` + iOS build 通过
    - [x]  1.7 需要有一个training页面，默认显示无训练中的plan
        - [x] 1.7.1 拆解/确认：明确页面入口与默认状态
        - [x] 1.7.2 实现：增加 Training 页面入口（默认空状态）
        - [x] 1.7.3 单测：为关键逻辑补充覆盖（可选 / UI wiring covered by build）
        - [x] 1.7.4 回归：`swift test` + iOS build 通过
    - [x]  1.8 create plan的时候无法设置音乐
        - [x] 1.8.1 定位原因：确认 create plan 流程中 music picker 入口/呈现方式
        - [x] 1.8.2 修复：music picker 改为导航 push（避免 nested sheet）
            - [x] 1.8.2.1 兼容：iOS 16 可用的导航方式（避免 `navigationDestination(item:)` iOS17 限制）
        - [x] 1.8.3 单测：为关键逻辑补充覆盖（可选 / UI wiring covered by build）
        - [x] 1.8.4 回归：`swift test` + iOS build 通过
    - [x]  1.9 Train页面中的plan没有编辑的入口
        - [x] 1.9.1 定位原因：确认 Train 页面缺少编辑入口的 UI 路径
        - [x] 1.9.2 实现：为 plan 行增加 Edit 入口（打开 PlanEditor）
        - [x] 1.9.3 单测：为关键逻辑补充覆盖（可选 / UI wiring covered by build）
        - [x] 1.9.4 回归：`swift test` + iOS build 通过

    - [x]  2.1 End 训练后仍可能卡死（彻底修复）
        - [x] 2.1.1 定位：排查 End 触发时 UI 状态竞争（Alert/Navigation/Timer）
        - [x] 2.1.2 修复：End 确认从 Alert 回调解耦 + Summary 展示期间停止 tick
        - [x] 2.1.3 单测：补充 engine “end 后 tick 不应再触发副作用” 覆盖
        - [x] 2.1.4 回归：`swift test` + iOS build 通过
    - [x]  2.2 MusicPicker：移除 placeholder，实现真实 My Playlists / Search
        - [x] 2.2.1 定位：确认当前 Search/My Playlists UI 仍为 mock/placeholder
        - [x] 2.2.2 实现：Search 用 MusicKit 搜索（track/album/playlist）
        - [x] 2.2.3 实现：My Playlists 去掉 placeholder + 支持选择 playlist
        - [x] 2.2.4 回归：`swift test` + iOS build 通过
    - [x]  2.3 全面“卡死”排查：减少主线程重任务 + 增加诊断信息（可复现/可定位）
        - [x] 2.3.1 定位：识别潜在死锁/阻塞点（AudioSessionManager 在锁内调用系统 API）
        - [x] 2.3.2 修复：AudioSessionManager 避免在持锁状态下调用 `applyRequest`
        - [x] 2.3.3 单测：覆盖 “合并请求 + apply 触发次数” 的行为
        - [x] 2.3.4 回归：`swift test` + iOS build 通过
        

## 🧠 Memory Bank (记忆库)

- *规则备忘*: Init
- *环境备忘*: Init
- *错误预判*: QuickStart 的 Start `.disabled(!canStartSelectedPlan)` 可能被自定义计划（历史数据超出范围）触发，导致“无法点击开始”。

## 🛑 Rules (行动准则 - 绝对遵守)

1. **自我驱动**：每完成一个动作，**必须**修改本文件的 `Phase`、`Last Action`、`Next Step` 和 `Task List` (打钩)。
2. **保持循环**：修改完代码后，立即检查 `Next Step` 并执行它。如果遇到 Test 失败，不要跳过，必须进入 "Fix -> Retest" 循环直到通过。
3. **完成标准**：每完成一个动作，都需要生成一个测例，全部测例都执行成功同时项目build成功才能执行下一步。
4. **打钩标准**: 只有一个任务下面所有的子任务都打钩了，当前任务才能被打钩
