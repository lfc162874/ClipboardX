# ClipboardX Architecture

## 1. Overview

ClipboardX is a native macOS menu bar utility. The repository now contains a standard Xcode macOS App project at `ClipboardX.xcodeproj`, while `Package.swift` remains available for lightweight SwiftPM build checks.

The application has four core responsibilities:

1. Monitor clipboard changes.
2. Normalize, classify, and filter clipboard data.
3. Persist clipboard history and local image resources.
4. Provide fast search, copy, and paste workflows from a menu bar UI.

## 2. Project Shape

```text
ClipboardX
├── ClipboardX.xcodeproj
├── ClipboardX
│   ├── Assets.xcassets
│   │   └── AppIcon.appiconset
│   └── Info.plist
├── Package.swift
├── Sources
│   └── ClipboardX
│       ├── App
│       ├── Clipboard
│       ├── Screenshot
│       ├── Security
│       ├── Sharing
│       ├── Storage
│       └── UI
└── docs
```

The Xcode target builds `ClipboardX.app` as a macOS application bundle. `Info.plist` sets `LSUIElement` so the app runs as a menu bar utility instead of showing a normal Dock icon. `Assets.xcassets` provides the app icon used by builds and archives.

## 3. Runtime Architecture

```text
NSPasteboard.general
        ↓
ClipboardMonitor
        ↓
ClipboardContentClassifier
        ↓
SensitiveFilter
        ↓
HashService
        ↓
ClipboardStore
        ↓
HistoryView / SettingsView
        ↓
ClipboardWriter
        ↓
PasteController
        ↓
Foreground macOS app
```

## 4. Modules

### 4.1 App

Files:

- `Sources/ClipboardX/App/ClipboardXApp.swift`
- `Sources/ClipboardX/App/AppState.swift`
- `Sources/ClipboardX/App/HotKeyController.swift`
- `Sources/ClipboardX/App/PasteController.swift`

Responsibilities:

- Initialize the SwiftUI app lifecycle.
- Own shared app state and settings.
- Create the menu bar entry and app commands.
- Register the `Option + V` global shortcut.
- Restore the previously active app and optionally simulate `Cmd + V` after selecting history.

### 4.2 Clipboard

Files:

- `Sources/ClipboardX/Clipboard/ClipboardContent.swift`
- `Sources/ClipboardX/Clipboard/ClipboardContentClassifier.swift`
- `Sources/ClipboardX/Clipboard/ClipboardMonitor.swift`
- `Sources/ClipboardX/Clipboard/ClipboardWriter.swift`

Responsibilities:

- Poll `NSPasteboard.changeCount`.
- Read text, URLs, file URLs, and images.
- Convert clipboard data into normalized `ClipboardContent`.
- Write selected history items back to `NSPasteboard.general`.
- Avoid re-recording clipboard writes initiated by ClipboardX itself.

### 4.3 Security

Files:

- `Sources/ClipboardX/Security/SensitiveFilter.swift`

Responsibilities:

- Apply default sensitive-content rules.
- Apply user-defined sensitive rules.
- Ignore content copied from user-configured source apps.
- Keep privacy controls local through `UserDefaults`.

### 4.4 Storage

Files:

- `Sources/ClipboardX/Storage/ClipboardItem.swift`
- `Sources/ClipboardX/Storage/ClipboardItemType.swift`
- `Sources/ClipboardX/Storage/ClipboardStore.swift`
- `Sources/ClipboardX/Storage/HashService.swift`

Responsibilities:

- Store clipboard metadata in SQLite.
- Save image payloads in an application support image directory.
- Deduplicate by content hash.
- Pin, delete, clear, search, and trim history.
- Migrate legacy JSON history into SQLite on first launch.
- Clean unused image resources after deletes and trims.

### 4.5 UI

Files:

- `Sources/ClipboardX/UI/HistoryView.swift`
- `Sources/ClipboardX/UI/SettingsView.swift`
- `Sources/ClipboardX/UI/LANSharingView.swift`

Responsibilities:

- Show searchable clipboard history.
- Filter by content type.
- Show source app, preview text, and image thumbnails.
- Expose copy, delete, pin, clear, pause, and settings workflows.
- Manage custom sensitive rules and ignored source apps.
- Provide a dedicated LAN sharing window for device discovery, trust, and receive policy.

### 4.6 Screenshot

Files:

- `Sources/ClipboardX/Screenshot/ScreenshotService.swift`
- `Sources/ClipboardX/Screenshot/ScreenshotPinController.swift`

Responsibilities:

- Trigger macOS region screenshot through the system screenshot tool.
- Read the screenshot from `NSPasteboard.general` as PNG data.
- Store screenshots as image history items.
- Create temporary floating screenshot pin windows for side-by-side comparison.
- Support multiple pins, resizing, closing, copying, and floating-level toggling.

### 4.7 Sharing

Files:

- `Sources/ClipboardX/Sharing/SharedDevice.swift`
- `Sources/ClipboardX/Sharing/ClipboardTransferPayload.swift`
- `Sources/ClipboardX/Sharing/LANSharingService.swift`

Responsibilities:

- Advertise ClipboardX on the local network through Bonjour.
- Discover other local ClipboardX devices.
- Manage lightweight device trust and pairing requests.
- Send text, URL, and image clipboard payloads to trusted devices.
- Reject clipboard payloads from untrusted devices.
- Queue received payloads for user confirmation before converting them into local history records.

## 5. Main Flows

### 5.1 Capture Clipboard Content

```text
User copies content
    ↓
macOS updates NSPasteboard.general
    ↓
ClipboardMonitor detects changeCount update
    ↓
ClipboardContentClassifier reads supported content
    ↓
SensitiveFilter checks content and source app
    ↓
HashService generates a stable hash
    ↓
ClipboardStore inserts a new item or refreshes an existing one
    ↓
HistoryView refreshes from in-memory state
```

Supported captured types:

- Plain text.
- URL text.
- File URLs.
- Images saved as PNG resources.

### 5.2 Reuse History Item

```text
User opens history with menu bar item or Option + V
    ↓
User selects a history item
    ↓
ClipboardWriter writes the item to NSPasteboard.general
    ↓
ClipboardStore updates the item timestamp
    ↓
Optional PasteController restores the prior app and sends Cmd + V
```

Automatic paste is guarded by macOS Accessibility permission. If permission is missing, ClipboardX opens the system permission prompt instead of sending keyboard events.

### 5.3 Manage Privacy

```text
User opens Settings
    ↓
User adds sensitive rules or ignored source apps
    ↓
Settings are saved to UserDefaults
    ↓
Future clipboard captures are filtered before persistence
```

### 5.4 Capture Screenshot Pin

```text
User chooses Screenshot and Pin or presses Option + Shift + A
    ↓
ScreenshotService launches macOS region capture
    ↓
macOS writes screenshot image to NSPasteboard.general
    ↓
ClipboardStore saves the image as a history item
    ↓
ScreenshotPinController opens a floating image pin
```

### 5.5 Send Over LAN

```text
User opens LAN Sharing from the menu bar and enables sharing
    ↓
LANSharingService advertises and discovers Bonjour services
    ↓
User trusts a discovered device
    ↓
User sends a text, URL, or image history item
    ↓
Receiver validates the source device is trusted
    ↓
Receiver adds the payload to pending receive requests
    ↓
User accepts the incoming content
    ↓
ClipboardStore saves the payload to local history
```

## 6. Storage Strategy

SQLite is the primary local store:

- Database path: `~/Library/Application Support/ClipboardX/clipboard-history.sqlite`.
- Image path: `~/Library/Application Support/ClipboardX/Images/`.
- `clipboard_items` stores id, type, content path/value, preview, hash, source app, pin state, and timestamps.
- `metadata` stores internal migration state.
- WAL mode is enabled for safer frequent writes.
- Search currently uses the loaded in-memory list; SQLite FTS5 can be added later for larger histories.

## 7. Privacy Strategy

ClipboardX uses local-first defaults:

- Clipboard history stays on device.
- Network sync is not enabled by default.
- Default sensitive rules block common tokens, passwords, private keys, and verification codes.
- Users can pause monitoring, clear history, add custom sensitive rules, and ignore selected source apps.
- LAN sharing is off by default and only sends manually selected history items.
- LAN send uses the existing sensitive-content filter for text and URL items.
- LAN receive rejects payloads from untrusted devices.
- Future CloudKit or LAN sync should remain explicit opt-in.

## 8. Extension Points

### 8.1 CloudKit Sync

```text
ClipboardStore
    ↓
SyncService
    ↓
iCloud private database
```

Before sync is enabled, sensitive filtering, user opt-in, conflict handling, and encryption strategy should be finalized.

### 8.2 LAN Sharing

```text
Bonjour discovery
    ↓
Authenticated device pairing
    ↓
Encrypted local channel
    ↓
Clipboard item exchange
```

LAN sharing should keep the same local-first privacy model and require explicit device trust.

### 8.3 Search Scaling

The current in-memory search is sufficient for the configured 1,000 item local history. If the history limit grows, add SQLite FTS5 indexing over preview/content/source fields.
