# ClipboardX

ClipboardX 是一个轻量、隐私优先的 macOS 剪贴板历史工具，用于记录复制历史、快速搜索、快捷复制/粘贴，并为后续多设备同步能力预留扩展。

## 产品定位

> 复制过的内容不再丢失。文本、链接、图片、文件都能快速找回，并可在多台 Mac 间安全同步。

## 当前阶段

当前仓库已转换为标准 Xcode macOS App 工程，并已实现菜单栏常驻 App 的核心能力：

- 菜单栏入口
- 剪贴板监听
- 文本历史记录
- URL 与文件路径识别
- 图片剪贴板记录与写回
- 内容去重
- 隐私过滤
- 本地 SQLite 持久化
- 搜索、类型过滤与图片缩略图
- Option + V 全局快捷键唤起历史窗口
- 收藏置顶与单条删除
- 来源应用展示
- 自动粘贴开关，需要辅助功能权限
- 设置窗口
- 自定义敏感过滤规则
- 忽略来源应用
- `ClipboardX.app` 应用包构建
- App 图标资源

后续可以继续扩展 CloudKit 同步、局域网同步和正式分发签名等能力。

## 技术选型

| 模块 | 技术 |
|---|---|
| 语言 | Swift |
| UI | SwiftUI + AppKit |
| 剪贴板 | NSPasteboard |
| 菜单栏 | NSStatusItem |
| 数据存储 | SQLite + 本地图片资源目录 |
| 工程 | Xcode macOS App target，保留 SwiftPM 辅助构建 |
| 同步 | 后续 CloudKit / 局域网同步 |

## 目录结构

```text
ClipboardX
├── ClipboardX.xcodeproj
├── ClipboardX
│   ├── Assets.xcassets
│   │   └── AppIcon.appiconset
│   └── Info.plist
├── Package.swift
├── README.md
├── docs
│   ├── ARCHITECTURE.md
│   ├── PRD.md
│   └── REQUIREMENTS.md
└── Sources
    └── ClipboardX
        ├── App
        ├── Clipboard
        ├── Security
        ├── Storage
        └── UI
```

## 本地运行

```bash
open ClipboardX.xcodeproj
```

然后选择 `ClipboardX` scheme 和 `My Mac` 运行。工程会构建标准 macOS 应用包 `ClipboardX.app`，并以菜单栏 App 形式启动。

也可以继续使用 SwiftPM 做辅助编译检查：

```bash
swift build
```

如果你本地曾经手动创建过同名 Swift 文件，例如：

```text
Sources/ClipboardX/ClipboardWriter.swift
Sources/ClipboardX/Clipboard/ClipboardWriter.swift
```

需要删除多余文件，Swift Package 的同一个 target 内不允许出现两个相同文件名。

## Roadmap

- [x] 初始化仓库结构
- [x] 编写需求文档
- [x] 建立 macOS 菜单栏 App 基础骨架
- [x] 转换为标准 Xcode macOS App 工程
- [x] 接入 App 图标资源
- [x] 支持本地 SQLite 持久化
- [x] 支持旧 JSON 历史自动迁移
- [x] 支持快捷键 Option + V
- [x] 支持 URL 类型识别
- [x] 支持文件路径记录
- [x] 支持图片类型
- [x] 支持收藏置顶
- [x] 支持单条删除
- [x] 支持搜索面板增强
- [x] 支持自动粘贴，需要 Accessibility 权限
- [x] 支持设置窗口
- [x] 支持自定义敏感过滤规则
- [x] 支持忽略来源应用
- [ ] 支持 CloudKit 多设备同步
