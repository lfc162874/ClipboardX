import AppKit
import Foundation

enum ScreenshotServiceError: LocalizedError {
    case cancelled
    case captureFailed
    case missingImageData

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "截图已取消"
        case .captureFailed:
            return "截图失败，请重试"
        case .missingImageData:
            return "没有从剪贴板读取到截图"
        }
    }
}

enum ScreenshotService {
    static func captureRegionToPasteboard() async throws -> ClipboardContent {
        let terminationStatus = try await runSystemScreenshot()

        guard terminationStatus == 0 else {
            throw ScreenshotServiceError.cancelled
        }

        return try await MainActor.run {
            guard let imageData = readPNGImageData(from: NSPasteboard.general) else {
                throw ScreenshotServiceError.missingImageData
            }

            return ClipboardContent(
                type: .image,
                content: HashService.sha256(imageData),
                sourceApp: "ClipboardX 截图",
                data: imageData
            )
        }
    }

    private static func runSystemScreenshot() async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = ["-i", "-s", "-c"]

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                } catch {
                    continuation.resume(throwing: ScreenshotServiceError.captureFailed)
                }
            }
        }
    }

    @MainActor
    private static func readPNGImageData(from pasteboard: NSPasteboard) -> Data? {
        let pngType = NSPasteboard.PasteboardType("public.png")
        if let pngData = pasteboard.data(forType: pngType) {
            return pngData
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
