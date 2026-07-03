# ClipboardX 需求文档

## 1. 项目背景

Mac 用户在日常开发、办公、写文档、复制代码、复制链接时，经常会遇到复制内容被新内容覆盖的问题。ClipboardX 的目标是提供一个轻量、隐私优先、可搜索、可扩展同步的 macOS 剪贴板历史工具。

## 2. 产品目标

ClipboardX 第一阶段目标是实现一个可长期运行在 macOS 菜单栏中的剪贴板历史工具。

核心目标：

1. 自动记录用户复制过的内容。
2. 支持快速搜索历史内容。
3. 支持点击历史记录后重新写入系统剪贴板。
4. 默认本地存储，不上传云端。
5. 对敏感内容进行过滤，降低隐私风险。
6. 为后续多设备同步、快捷键粘贴、图片/文件支持预留架构。

## 3. 产品定位

> 一个轻量、隐私优先的 macOS 剪贴板历史与共享工具。

一句话描述：

> 复制过的内容不再丢失，文本、链接、图片、文件都能快速找回，并可在多台 Mac 间安全同步。

## 4. 用户场景

### 4.1 开发场景

用户复制过接口地址、Token 片段、SQL、日志、代码片段，希望稍后快速找回。

### 4.2 办公场景

用户在多个文档之间复制内容，希望快速复用之前复制过的文本、链接、文件路径。

### 4.3 写作场景

用户复制多个资料片段，希望在写作过程中快速调取历史内容。

### 4.4 多设备场景

用户有多台 Mac，希望历史内容可以通过 iCloud 或局域网同步。

## 5. MVP 功能范围

第一版只做最小可用版本：

| 功能 | 说明 | 优先级 |
|---|---|---|
| 菜单栏常驻 | App 启动后显示在 macOS 菜单栏 | P0 |
| 剪贴板监听 | 通过 NSPasteboard.changeCount 监听变化 | P0 |
| 文本记录 | 记录纯文本内容 | P0 |
| 内容去重 | 相同内容不重复插入，只更新时间 | P0 |
| 历史列表 | 展示最近复制记录 | P0 |
| 搜索 | 按关键词过滤历史记录 | P0 |
| 点击复制 | 点击历史记录后重新写入系统剪贴板 | P0 |
| 暂停监听 | 用户可临时暂停记录 | P1 |
| 清空历史 | 用户可清空全部历史 | P1 |
| 隐私过滤 | 过滤密码、私钥、Token 等内容 | P1 |

## 6. 后续增强功能

| 功能 | 说明 | 优先级 |
|---|---|---|
| 全局快捷键 | Option + V 唤起搜索面板 | P1 |
| 自动粘贴 | 复制后模拟 Cmd + V，需要 Accessibility 权限 | P2 |
| 图片支持 | 记录图片并保存到应用目录 | P2 |
| URL 分类 | 自动识别 URL 类型 | P2 |
| 文件路径支持 | 记录复制的文件路径 | P2 |
| 收藏置顶 | 常用内容置顶 | P2 |
| SQLite / SwiftData | 持久化历史数据 | P1 |
| CloudKit 同步 | 多台 Mac 间同步历史 | P3 |
| 局域网同步 | Bonjour + WebSocket 设备发现与同步 | P3 |

## 7. 功能设计

### 7.1 剪贴板监听

使用 `NSPasteboard.general.changeCount` 判断系统剪贴板是否发生变化。

监听策略：

- 每 0.5 秒轮询一次。
- changeCount 变化后读取剪贴板内容。
- 第一阶段只读取 `.string` 类型。
- 内容为空时不保存。
- 命中敏感过滤规则时不保存。
- 命中重复内容时只更新时间，不重复插入。

### 7.2 历史记录

历史记录字段：

| 字段 | 说明 |
|---|---|
| id | 唯一 ID |
| type | 内容类型，text/url/image/file/html/richText |
| content | 原始内容或资源路径 |
| preview | 预览文本 |
| hash | 内容哈希，用于去重 |
| sourceApp | 来源应用，后续支持 |
| isPinned | 是否置顶 |
| createdAt | 创建时间 |
| updatedAt | 更新时间 |

### 7.3 搜索

搜索策略：

- MVP 采用内存过滤。
- 后续存储层改为 SQLite FTS5 或 SwiftData 查询。
- 搜索字段包括 content、preview、type。

### 7.4 点击复制

用户点击某条历史记录后：

1. 清空系统剪贴板。
2. 将历史内容写入 `NSPasteboard.general`。
3. 更新该记录的 `updatedAt`。

### 7.5 隐私过滤

默认过滤以下内容：

- `password=`
- `Authorization:`
- `Bearer `
- `sk-`
- `AKIA`
- `-----BEGIN PRIVATE KEY-----`
- `验证码`
- `verification code`

后续支持用户自定义过滤规则。

## 8. 非功能需求

### 8.1 性能

- 剪贴板监听不应明显影响系统性能。
- 历史记录列表打开响应时间应低于 300ms。
- 第一版建议最多保留 1000 条文本历史。

### 8.2 隐私

- 默认只本地保存。
- 默认不上传云端。
- 提供清空历史能力。
- 提供暂停监听能力。
- 后续提供应用黑名单。

### 8.3 可靠性

- App 异常退出不应影响系统剪贴板。
- 写入剪贴板失败时不应崩溃。
- 监听器应支持启动与停止。

## 9. 技术架构

```text
ClipboardX
├── App
│   ├── ClipboardXApp.swift
│   └── AppState.swift
├── Clipboard
│   ├── ClipboardMonitor.swift
│   └── ClipboardWriter.swift
├── Security
│   └── SensitiveFilter.swift
├── Storage
│   ├── ClipboardItem.swift
│   ├── ClipboardItemType.swift
│   ├── ClipboardStore.swift
│   └── HashService.swift
└── UI
    ├── HistoryWindow.swift
    ├── HistoryView.swift
    └── SettingsView.swift
```

## 10. 开发里程碑

### Milestone 1：基础可运行

- 初始化 Swift Package。
- App 启动后显示菜单栏图标。
- 后台监听剪贴板文本。
- 内存保存历史。
- 菜单中展示打开历史窗口、暂停监听、清空历史、退出。

### Milestone 2：基础可用

- 历史窗口支持搜索。
- 点击记录写回剪贴板。
- 支持去重。
- 支持敏感内容过滤。

### Milestone 3：本地持久化

- 引入 SQLite / SwiftData。
- 支持最多保存 N 条。
- 支持自动清理。

### Milestone 4：增强体验

- 全局快捷键。
- 自动粘贴。
- 图片、URL、文件类型。

### Milestone 5：共享同步

- CloudKit 同步。
- 局域网同步。
- 设备管理与加密传输。
