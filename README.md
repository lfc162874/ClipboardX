# ClipboardX

ClipboardX 是一个轻量、隐私优先的 macOS 剪贴板历史工具，用于记录复制历史、快速搜索、快捷复制/粘贴，并为后续多设备同步能力预留扩展。

## 产品定位

> 复制过的内容不再丢失。文本、链接、图片、文件都能快速找回，并可在多台 Mac 间安全同步。

## 当前阶段

当前仓库已初始化为 Swift Package 结构，先实现 macOS 菜单栏常驻 App 的核心骨架：

- 菜单栏入口
- 剪贴板监听
- 文本历史记录
- 内容去重
- 隐私过滤
- 本地内存存储骨架
- 搜索面板 UI 骨架

后续可以逐步替换为 SQLite / SwiftData 持久化，并扩展图片、文件、URL、CloudKit 同步等能力。

## 技术选型

| 模块 | 技术 |
|---|---|
| 语言 | Swift |
| UI | SwiftUI + AppKit |
| 剪贴板 | NSPasteboard |
| 菜单栏 | NSStatusItem |
| 数据存储 | 第一阶段内存存储，后续 SQLite / SwiftData |
| 同步 | 后续 CloudKit / 局域网同步 |

## 目录结构

```text
ClipboardX
├── Package.swift
├── README.md
├── docs
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
swift run ClipboardX
```

也可以使用 Xcode 打开 Swift Package：

```bash
open Package.swift
```

然后选择 `ClipboardX` scheme 和 `My Mac` 运行。

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
- [ ] 支持 SQLite / SwiftData 持久化
- [ ] 支持快捷键 Option + V
- [ ] 支持搜索面板增强
- [ ] 支持图片 / 文件 / URL 类型
- [ ] 支持自动粘贴，需要 Accessibility 权限
- [ ] 支持 CloudKit 多设备同步
