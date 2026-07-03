import Foundation

struct SharedDeviceIdentity: Codable, Equatable {
    let id: String
    let name: String
}

struct SharedDevice: Identifiable, Equatable {
    let id: String
    var name: String
    var isTrusted: Bool
    var lastSeenAt: Date
}

struct PairingRequest: Identifiable, Equatable {
    let device: SharedDevice
    let receivedAt: Date

    var id: String { device.id }
}

struct IncomingClipboardRequest: Identifiable {
    let id = UUID()
    let sourceDevice: SharedDeviceIdentity
    let payload: ClipboardTransferPayload
    let receivedAt: Date
}
