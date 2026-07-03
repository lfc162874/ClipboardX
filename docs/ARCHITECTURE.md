# ClipboardX Architecture

## 1. Overview

ClipboardX is designed as a native macOS menu bar utility.

The application has four core responsibilities:

1. Monitor clipboard changes
2. Normalize and filter clipboard data
3. Persist clipboard history locally
4. Provide a fast UI for search and reuse

## 2. High-level Architecture

```text
NSPasteboard.general
        ↓
ClipboardMonitor
        ↓
ClipboardReader
        ↓
SensitiveFilter
        ↓
DedupService / HashService
        ↓
ClipboardStore
        ↓
HistoryWindow / HistoryListView
        ↓
ClipboardWriter
        ↓
NSPasteboard.general
```

## 3. Modules

## 3.1 App

Entry point and lifecycle management.

Files:

- `ClipboardXApp.swift`
- `AppDelegate.swift`
- `MenuBarController.swift`

Responsibilities:

- Initialize the clipboard monitor
- Initialize the local store
- Create menu bar icon and menu
- Open the history window
- Handle app quit

## 3.2 Clipboard

Files:

- `ClipboardMonitor.swift`
- `ClipboardReader.swift`
- `ClipboardWriter.swift`

Responsibilities:

- Poll `NSPasteboard.changeCount`
- Read supported clipboard data types
- Write selected history items back to clipboard

MVP only supports plain text.

Future supported types:

- URL
- Image
- File path
- HTML
- Rich text

## 3.3 Models

Files:

- `ClipboardItem.swift`
- `ClipboardItemType.swift`

Responsibilities:

- Define clipboard history entities
- Define supported item types
- Provide preview generation

## 3.4 Storage

Files:

- `ClipboardStore.swift`
- `FileClipboardStore.swift`
- `HashService.swift`

Responsibilities:

- Store clipboard history locally
- Deduplicate by content hash
- Search and sort history items
- Enforce max history count

MVP storage is JSON-based for quick startup. Production storage should migrate to SQLite or SwiftData.

## 3.5 Security

Files:

- `SensitiveFilter.swift`

Responsibilities:

- Filter sensitive clipboard content before persistence
- Provide default rules for keys, tokens, passwords, and verification codes

## 3.6 UI

Files:

- `HistoryWindowController.swift`
- `HistoryView.swift`
- `HistoryListView.swift`

Responsibilities:

- Display clipboard history
- Search history
- Copy selected history item
- Clear history

## 4. Runtime Flow

## 4.1 Copy New Text

```text
User copies text
    ↓
macOS updates NSPasteboard.general
    ↓
ClipboardMonitor sees changeCount changed
    ↓
ClipboardReader reads text
    ↓
SensitiveFilter checks if it should be ignored
    ↓
HashService generates content hash
    ↓
ClipboardStore inserts new item or updates old item timestamp
    ↓
UI refreshes history list
```

## 4.2 Reuse History Item

```text
User opens history window
    ↓
User searches or selects item
    ↓
ClipboardWriter writes item content to NSPasteboard.general
    ↓
Current active app can paste the selected content manually
```

Automatic paste is intentionally not part of MVP because it requires Accessibility permissions and simulated keyboard events.

## 5. Storage Strategy

### MVP

- JSON file in Application Support directory
- Simple to inspect and debug
- Enough for early local development

### Production

Recommended migration path:

1. SQLite local database
2. SQLite FTS for search
3. Optional SQLCipher or encrypted blob storage
4. Separate local file directory for images and files

## 6. Privacy Strategy

Clipboard history can contain sensitive information. ClipboardX should adopt safe defaults:

- Local-only by default
- No network sync in MVP
- Sensitive content rules enabled by default
- Clear history operation exposed in menu
- Pause monitoring operation exposed in menu

## 7. Extension Points

### 7.1 CloudKit Sync

Future component:

```text
ClipboardStore
    ↓
CloudKitSyncService
    ↓
iCloud private database
```

Before syncing:

- Filter sensitive content
- Encrypt payloads where possible
- Allow users to opt in explicitly

### 7.2 LAN Sharing

Future component:

```text
Bonjour discovery
    ↓
WebSocket channel
    ↓
Device authentication
    ↓
Encrypted clipboard item exchange
```

Useful for private office or local-network workflows.

## 8. Current Scaffold Limitations

- Swift Package Manager can build and run the code as a native macOS executable
- A production `.app` bundle should be created later with Xcode
- Global shortcut is not implemented yet
- SQLite/SwiftData is not implemented yet
- Image/file clipboard types are not implemented yet
