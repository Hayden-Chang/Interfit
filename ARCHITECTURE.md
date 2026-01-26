# Interfit Architecture & Conventions (项目架构约定)

> Scope: M0 — 工程骨架与基础约定。  
> Target: **SwiftUI + MVVM**，模块化（Swift Package）优先，依赖方向清晰、可测试、可扩展。

## 1. Tech Stack (技术栈)

- UI: **SwiftUI**
- State: **MVVM**（View + ViewModel + Service/Repository）
- Modules: **Swift Package Manager (local packages)** in `Modules/`
- Minimum OS: **iOS 16**

## 2. Repository Layout (目录规范)

```text
Interfit/                     # repo root
  Interfit/                   # App target (SwiftUI)
  Interfit.xcodeproj/
  Modules/                    # local Swift Packages
    Shared/
    Persistence/
    Audio/
  ARCHITECTURE.md
  workflow_state.md
  design_all_phases_integrated.md
```

### 2.1 App Target (`Interfit/`)

- 放置 App 入口、路由、Feature 组装（Composition Root）与少量 Glue code
- **不**把可复用逻辑堆在 App target；优先下沉到 `Modules/*`

### 2.2 Local Packages (`Modules/*`)

每个模块遵循统一模板：

```text
Modules/<ModuleName>/
  Package.swift
  Sources/<ModuleName>/
  Tests/<ModuleName>Tests/
```

平台声明：`.iOS(.v16)`（与工程一致）。

## 3. Module Dependency Rules (模块依赖规则)

### 3.1 Allowed Direction (允许依赖方向)

- **App** → Feature Modules（Train/Plans/Me/…，后续创建）
- Feature Modules → Shared / Infrastructure Modules（如 `Shared`, `Persistence`, `Audio`）
- Infrastructure Modules（`Shared`/`Persistence`/`Audio`）**不得**反向依赖任何 Feature/App

用一句话记忆：

> **业务依赖基础能力，基础能力不认识业务。**

### 3.2 What Goes Where (职责边界)

- `Shared`
  - 纯工具/纯模型/协议（protocol）/轻量无状态 helper
  - 不包含 UIKit/SwiftUI 视图（除非是通用 UI primitives，后续再评估）
- `Persistence`
  - 本地存储抽象与实现（M0 先骨架，后续补 Plan/Session 持久化）
  - 对上暴露 Repository/Store 接口（协议优先）
- `Audio`
  - AudioSession / 提示音 / 震动 等“通道能力”的抽象与实现（M0 先占位）
  - 对上暴露最小稳定接口，避免业务层直接触达 AVFoundation/MusicKit

## 4. MVVM Conventions (SwiftUI + MVVM 约定)

### 4.1 Naming (命名)

- View: `<Feature><Screen>View`（例如 `TrainHomeView`）
- ViewModel: `<Feature><Screen>ViewModel`
- Service/Repository: `<Domain>Service` / `<Domain>Repository`

### 4.2 View Rules (View 规则)

- View 只做：布局、展示、用户输入收集、调用 VM intent
- View 不直接访问存储/网络/音频等 side effects
- View 不包含难以测试的业务逻辑（搬到 VM 或 Service）

### 4.3 ViewModel Rules (VM 规则)

- VM 负责：状态（state）、意图（intent/action）、业务编排
- Side effects 通过注入的 service/repository 完成
- VM 尽量可单测：避免直接读取 `Date()` / `UUID()` 等，必要时注入 Clock/IdProvider（后续放在 `Shared`）

### 4.4 Dependency Injection (依赖注入)

M0 采用**手动注入**（Composition Root 在 App）：

- App 负责创建：Repository / Service / ViewModel
- View 只接受 VM 或最小依赖

后续再考虑引入容器（如果复杂度上升）。

## 5. Copyable Templates (可抄的模板)

### 5.1 New Page Template (新增页面模板)

1) 创建 View + ViewModel（先在 App target，后续迁移到 Feature module）
2) 在 App 入口组装依赖

### 5.2 Minimal ViewModel Template (最小 VM 模板)

```swift
import Foundation

@MainActor
final class ExampleViewModel: ObservableObject {
    @Published private(set) var title: String = "Hello"

    func onAppear() {
        // load / refresh
    }
}
```

### 5.3 Minimal Service Template (最小 Service 模板)

```swift
public protocol ExampleService {
    func loadTitle() async throws -> String
}

public struct ExampleServiceNoop: ExampleService {
    public init() {}
    public func loadTitle() async throws -> String { "Hello" }
}
```

## 6. Build & Verification (构建与验证)

最小验收口径（M0）：

- `xcodebuild build` 通过（至少一个 iOS Simulator 目的地）
- 新增/修改模块后：对应模块 `swift test` 通过
- App 内存在最小示例页可用于验证模块集成（例如 `ModulesDemoView`）
