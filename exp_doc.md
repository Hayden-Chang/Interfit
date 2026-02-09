# iOS MusicKit 问题排查经验总结

## 问题背景

用户报告应用运行时出现大量错误日志，包括：
- `ICError Code=-7013 "Client is not entitled to access account store"`
- `404 Resource Not Found` 错误
- 网络请求被拒绝

## 错误的排查方向（不应该做的）

### 1. ❌ 被警告日志误导
- **错误做法**：看到大量 `ICError -7013` 错误，就认为这是主要问题
- **实际情况**：这些是系统级警告，不影响应用功能
- **教训**：区分警告和真正的错误，关注用户实际遇到的功能问题

### 2. ❌ 过度关注 entitlements 配置
- **错误做法**：反复尝试添加各种 entitlements（`com.apple.developer.music-user-token`, `com.apple.developer.musickit`）
- **实际情况**：MusicKit 在 App ID 中启用后，不需要在 entitlements 文件中声明
- **教训**：先理解 Apple 的文档和最佳实践，不要盲目添加配置

### 3. ❌ 试图"修复"不是问题的问题
- **错误做法**：尝试添加网络权限、修改 provisioning profile、删除 entitlements
- **实际情况**：这些都不是根本问题
- **教训**：在修改配置前，先确认问题的根本原因

### 4. ❌ 没有仔细分析错误信息
- **错误做法**：看到 404 错误，但没有深入分析 URL 和 ID 格式
- **实际情况**：错误 URL 中的 `i.` 前缀明确表明这是 library ID，不是 catalog ID
- **教训**：仔细阅读错误信息的每个细节，URL、ID 格式都是重要线索

### 5. ❌ 提供临时规避方案而不是解决根本问题
- **错误做法**：建议删除 entitlements、在模拟器上测试、清除应用数据
- **实际情况**：这些都是逃避问题，不是解决问题
- **教训**：用户需要的是解决方案，不是临时规避

## 正确的排查方法（应该做的）

### 1. ✅ 识别真正的错误
```
Failed to perform MusicDataRequest.Context(
  url: "https://api.music.apple.com/v1/catalog/cn/songs/i.JL1aVxKS8e60PrB?l=en-GB&omit%5Bresource%5D=autos",
  currentRetryCounts: [.other: 1]
) with MusicDataRequest.Error(
  status: 404,
  code: 40400,
  title: "Resource Not Found",
  detailText: "Resource with requested id was not found"
)
```

**关键线索**：
- 404 错误 - 资源不存在
- URL 中的 `i.JL1aVxKS8e60PrB` - `i.` 前缀表示 library ID
- 请求的是 `/catalog/` 端点 - 这是 Apple Music 目录 API

### 2. ✅ 理解 MusicKit 的 ID 系统
- **Library ID**：以 `i.` 开头，用于本地音乐库
- **Catalog ID**：不以 `i.` 开头，用于 Apple Music 目录
- **关键**：不能混用！Library ID 不能用于查询 catalog API

### 3. ✅ 追踪数据流
1. 用户从"我的播放列表"选择音乐
2. 代码保存 library ID（`source: .localLibrary`）
3. 播放时，先尝试从本地库获取
4. 本地库找不到（可能未下载）
5. **Bug**：代码尝试用 library ID 查询 catalog API
6. 返回 404 错误

### 4. ✅ 深入代码分析
```swift
// MusicPickerView.swift - 从本地库获取
MusicSelection(
    source: .localLibrary,  // ← 标记为本地库
    type: .playlist,
    externalId: playlist.id.rawValue,  // ← Library ID (i.xxx)
    ...
)

// MusicPlaybackClient.swift - 播放时的 Bug
if song == nil {
    // ❌ 没有检查 source，总是尝试 catalog
    let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
    // 用 library ID 查询 catalog → 404
}
```

### 5. ✅ 提供根本解决方案
**方案 1（立即可用）**：使用 Apple Music 搜索
- 从搜索结果选择歌曲（catalog ID）
- 不从"我的播放列表"选择（library ID）

**方案 2（代码修复）**：修复 bug
```swift
// 只有当 source 是 appleMusic 时才查询 catalog
if song == nil && selection.source == .appleMusic {
    let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
    ...
}
```

## 关键教训

### 1. 首要原则：理解问题，不要猜测
- ❌ "可能是权限问题" → 盲目添加 entitlements
- ✅ "404 错误，URL 中有 `i.` 前缀" → 分析 ID 类型不匹配

### 2. 区分症状和根本原因
- **症状**：大量警告日志、404 错误
- **根本原因**：代码用 library ID 查询 catalog API

### 3. 相信错误信息
- 错误信息说 "Resource Not Found"，就是找不到资源
- 不要假设是权限、网络、配置问题

### 4. 追踪数据流
- 数据从哪里来？（本地库 vs 搜索结果）
- 数据如何存储？（library ID vs catalog ID）
- 数据如何使用？（查询哪个 API？）

### 5. 代码审查比配置调整更重要
- 配置问题通常会导致构建失败
- 运行时错误通常是代码逻辑问题

### 6. 提供可操作的解决方案
- ❌ "可能需要升级账户"、"试试在模拟器上运行"
- ✅ "使用搜索功能选择歌曲，不要从播放列表选择"

## 问题排查流程（推荐）

```
1. 识别真正的错误
   ↓
2. 分析错误信息的每个细节
   ↓
3. 理解相关技术的工作原理（MusicKit ID 系统）
   ↓
4. 追踪数据流和代码逻辑
   ↓
5. 找到根本原因
   ↓
6. 提供可操作的解决方案
   ↓
7. 验证解决方案
```

## 最终解决方案

### 用户操作（立即可用）
1. 在应用中使用 **"Search Apple Music"** 功能
2. 搜索想要的歌曲
3. 从搜索结果中选择（这些是 catalog ID）
4. **不要**从"我的播放列表"选择（这些是 library ID）

### 代码修复（已完成）
修改 `MusicPlaybackClient.swift` 中的 `queueTrack`, `queueAlbum`, `queuePlaylist` 方法，添加 source 检查：

```swift
// 只有当 source 是 appleMusic 时才查询 catalog
if song == nil && selection.source == .appleMusic {
    // 查询 catalog
}
```

## 反思

这次问题排查花费了大量时间在错误的方向上：
- 反复尝试配置 entitlements
- 研究 provisioning profile
- 讨论账户类型
- 添加网络权限

而真正的问题只需要：
1. 仔细看错误 URL 中的 `i.` 前缀
2. 理解 library ID vs catalog ID
3. 检查代码逻辑

**核心教训**：在动手修改配置之前，先理解问题的本质。
