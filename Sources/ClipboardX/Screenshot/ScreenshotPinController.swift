import AppKit
import SwiftUI

@MainActor
final class ScreenshotPinController: NSObject, NSWindowDelegate {
    private var windows: [UUID: NSPanel] = [:]
    private var cascadeOffset: CGFloat = 0

    func show(item: ClipboardItem) {
        guard item.type == .image,
              let image = NSImage(contentsOfFile: item.content) else {
            return
        }

        let size = initialWindowSize(for: image)
        let origin = initialWindowOrigin(size: size)
        let frame = NSRect(origin: origin, size: size)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "截图贴片"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 180, height: 120)
        panel.delegate = self

        let view = ScreenshotPinView(
            item: item,
            image: image,
            copyAction: {
                ClipboardWriter.write(item)
            },
            closeAction: { [weak panel] in
                panel?.close()
            },
            levelAction: { [weak panel] isPinned in
                panel?.level = isPinned ? .floating : .normal
                panel?.isFloatingPanel = isPinned
            }
        )

        panel.contentView = NSHostingView(rootView: view)
        windows[item.id] = panel
        panel.makeKeyAndOrderFront(nil)
        cascadeOffset = cascadeOffset >= 96 ? 0 : cascadeOffset + 24
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        windows = windows.filter { $0.value !== closedWindow }
    }

    private func initialWindowSize(for image: NSImage) -> NSSize {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: 420, height: 280)
        }

        let maxWidth: CGFloat = 560
        let maxHeight: CGFloat = 420
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1)
        return NSSize(
            width: max(220, imageSize.width * scale),
            height: max(160, imageSize.height * scale)
        )
    }

    private func initialWindowOrigin(size: NSSize) -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return NSPoint(x: 160 + cascadeOffset, y: 160 - cascadeOffset)
        }

        return NSPoint(
            x: visibleFrame.maxX - size.width - 40 - cascadeOffset,
            y: visibleFrame.maxY - size.height - 40 - cascadeOffset
        )
    }
}

private struct ScreenshotPinView: View {
    let item: ClipboardItem
    let image: NSImage
    let copyAction: () -> Void
    let closeAction: () -> Void
    let levelAction: (Bool) -> Void

    @State private var isPinned = true
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .controlBackgroundColor)

            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isHovering {
                toolbar
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(action: copyAction) {
                Image(systemName: "doc.on.doc")
                    .frame(width: 28, height: 28)
            }
            .help("复制截图到剪贴板")

            Button {
                isPinned.toggle()
                levelAction(isPinned)
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .frame(width: 28, height: 28)
            }
            .help(isPinned ? "取消置顶" : "置顶")

            Button(role: .destructive, action: closeAction) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .help("关闭贴片")
        }
        .buttonStyle(.borderless)
        .padding(5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}
