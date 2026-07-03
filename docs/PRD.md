# ClipboardX Product Requirements Document

## 1. Background

Users frequently copy useful text, links, commands, snippets, file paths, and images while working on macOS. The system clipboard only keeps the latest item, so important content can easily be lost after the next copy operation.

ClipboardX solves this by recording clipboard history locally and providing a fast search-and-reuse experience from the menu bar.

## 2. Product Positioning

ClipboardX is a lightweight, privacy-first macOS clipboard history and clipboard sharing utility.

Initial positioning:

> A native macOS menu bar clipboard history tool that helps users quickly find and reuse copied content without sending private clipboard data to external servers by default.

## 3. Target Users

- Developers who frequently copy code, commands, logs, API keys, URLs, and config snippets
- Office users who copy text between documents, browsers, and chat tools
- AI/agent users who repeatedly copy prompts, generated outputs, and error logs
- Power users who need fast search, paste, and reuse workflows

## 4. Core Goals

### 4.1 MVP Goals

- Monitor clipboard changes in the background
- Save useful text clipboard history locally
- Deduplicate repeated content
- Provide a searchable history window
- Allow users to copy any history item back to the system clipboard
- Provide basic privacy filtering for sensitive content
- Run as a macOS menu bar resident utility

### 4.2 Non-goals for MVP

- Full iCloud sync
- LAN clipboard sharing
- OCR for copied images
- Rich text fidelity preservation
- Automatic paste through Accessibility permissions
- Full `.app` distribution packaging

These features are planned for later iterations.

## 5. User Stories

### 5.1 Clipboard Recording

As a user, when I copy a piece of text, ClipboardX should automatically record it so that I can find it later.

Acceptance criteria:

- Empty text is ignored
- Whitespace-only text is ignored
- Repeated text is deduplicated
- The latest copy time is updated for existing content
- Sensitive content can be filtered before persistence

### 5.2 Search History

As a user, I want to search previous clipboard items by keyword.

Acceptance criteria:

- Search should match item content and preview text
- Search should be case-insensitive
- Results should be ordered by latest copy time by default

### 5.3 Copy From History

As a user, I want to click a history item and copy it back to the system clipboard.

Acceptance criteria:

- Clicking a history item writes its content to `NSPasteboard.general`
- The selected item becomes the latest clipboard item
- The app avoids recording duplicate self-writes as separate new rows

### 5.4 Privacy Filtering

As a user, I do not want passwords, private keys, tokens, or verification codes to be saved accidentally.

Acceptance criteria:

- The app has default sensitive-content rules
- Filtered content is not persisted
- Users can pause clipboard monitoring
- Users can clear all local history

## 6. Functional Requirements

## 6.1 Menu Bar App

- The app should create a menu bar icon
- The menu should expose:
  - Open Clipboard History
  - Pause / Resume Monitoring
  - Clear History
  - Quit

## 6.2 Clipboard Monitor

- Use `NSPasteboard.general`
- Poll `changeCount` at a short interval
- Read plain text through `.string`
- Ignore unsupported types in MVP

## 6.3 History Storage

MVP storage may use a local JSON file for quick scaffolding.

Planned production storage:

- SQLite or SwiftData
- Separate blob storage for images/files
- Optional encrypted database

Recommended future table:

```sql
CREATE TABLE clipboard_item (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    content TEXT,
    preview TEXT,
    hash TEXT NOT NULL,
    source_app TEXT,
    is_pinned INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

## 6.4 Deduplication

- Generate a stable SHA-256 hash from item type and content
- If the hash exists, update `updatedAt`
- If the hash does not exist, insert a new item

## 6.5 Search

- Local in-memory search is acceptable for MVP
- SQLite FTS can be introduced later

## 7. Privacy Requirements

Default filtering should include:

- `password=`
- `Authorization:`
- `Bearer `
- `sk-`
- `AKIA`
- `-----BEGIN PRIVATE KEY-----`
- `验证码`
- `verification code`

Additional planned privacy controls:

- App blacklist
- Manual pause mode
- Max history limit
- Auto-delete after N days
- Optional encrypted storage

## 8. Product Roadmap

### Phase 1: Local Text History

- Menu bar app
- Clipboard text monitor
- Local persistence
- Search window
- Copy back to clipboard
- Privacy filter

### Phase 2: Better macOS Experience

- Global shortcut, for example `Option + V`
- Keyboard navigation
- Pin/favorite items
- Delete single item
- Clear history confirmation
- Settings page

### Phase 3: Rich Clipboard Types

- URL classification
- Image history
- File path history
- HTML/rich text preview

### Phase 4: Multi-device Sharing

- CloudKit sync for Apple ecosystem users
- LAN sharing through Bonjour + WebSocket for private network workflows
- End-to-end encryption before sync

## 9. Success Metrics

- Clipboard text can be captured reliably during normal usage
- Search result appears within 100 ms for 1,000 local records
- Menu bar app uses low memory and CPU while idle
- No known sensitive test samples are persisted by default

## 10. Development Principles

- Native first
- Privacy first
- Small MVP first
- Local-first data model
- Avoid unnecessary background network access
