import Foundation
import Network

final class LANSharingService {
    private let serviceType = "_clipboardx._tcp"
    private let maxMessageSize = 20 * 1024 * 1024
    private let queue = DispatchQueue(label: "com.yuanshan.ClipboardX.lan-sharing")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var endpointsByDeviceID: [String: NWEndpoint] = [:]
    private var devicesByID: [String: SharedDevice] = [:]
    private var trustedDeviceIDs: Set<String>
    private var localDevice: SharedDeviceIdentity

    var onDevicesChanged: (([SharedDevice]) -> Void)?
    var onPairingRequest: ((SharedDevice) -> Void)?
    var onReceivedPayload: ((ClipboardTransferPayload, SharedDeviceIdentity) -> Void)?
    var onError: ((String) -> Void)?

    init(localDevice: SharedDeviceIdentity, trustedDeviceIDs: Set<String>) {
        self.localDevice = localDevice
        self.trustedDeviceIDs = trustedDeviceIDs
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var isRunning: Bool {
        listener != nil || browser != nil
    }

    func update(localDevice: SharedDeviceIdentity, trustedDeviceIDs: Set<String>) {
        queue.async { [weak self] in
            guard let self else { return }
            let shouldRestart = self.isRunning && self.localDevice != localDevice
            self.localDevice = localDevice
            self.trustedDeviceIDs = trustedDeviceIDs
            self.refreshTrustedState()

            if shouldRestart {
                self.stopOnQueue()
                self.startOnQueue()
            }
        }
    }

    func start() {
        queue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopOnQueue()
        }
    }

    func trustDevice(_ deviceID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.trustedDeviceIDs.insert(deviceID)
            self.refreshTrustedState()
        }
    }

    func removeTrustedDevice(_ deviceID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.trustedDeviceIDs.remove(deviceID)
            self.refreshTrustedState()
        }
    }

    func sendPairingRequest(to deviceID: String) {
        let message = LANMessage(
            kind: .pairingRequest,
            sourceDevice: localDevice,
            payload: nil
        )
        send(message, to: deviceID)
    }

    func send(payload: ClipboardTransferPayload, to deviceID: String) {
        let message = LANMessage(
            kind: .clipboardItem,
            sourceDevice: localDevice,
            payload: payload
        )
        send(message, to: deviceID)
    }

    private func startOnQueue() {
        guard listener == nil, browser == nil else { return }

        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(
                name: serviceName,
                type: serviceType,
                txtRecord: NWTXTRecord([
                    "id": localDevice.id,
                    "name": localDevice.name
                ])
            )
            listener.newConnectionHandler = { [weak self] connection in
                self?.receive(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case let .failed(error) = state {
                    self?.reportError("局域网共享启动失败：\(error.localizedDescription)")
                }
            }
            listener.start(queue: queue)
            self.listener = listener

            let browser = NWBrowser(
                for: .bonjour(type: serviceType, domain: nil),
                using: .tcp
            )
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                self?.handleBrowseResults(results)
            }
            browser.stateUpdateHandler = { [weak self] state in
                if case let .failed(error) = state {
                    self?.reportError("局域网设备发现失败：\(error.localizedDescription)")
                }
            }
            browser.start(queue: queue)
            self.browser = browser
        } catch {
            reportError("局域网共享启动失败：\(error.localizedDescription)")
        }
    }

    private func stopOnQueue() {
        listener?.cancel()
        browser?.cancel()
        listener = nil
        browser = nil
        endpointsByDeviceID = [:]
        devicesByID = [:]
        notifyDevicesChanged()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var nextEndpoints: [String: NWEndpoint] = [:]
        var nextDevices: [String: SharedDevice] = [:]

        for result in results {
            let metadata = bonjourMetadata(from: result)
            let endpointName = serviceName(from: result.endpoint)
            let deviceID = metadata["id"] ?? endpointName
            guard deviceID != localDevice.id else { continue }

            let name = metadata["name"] ?? endpointName
            nextEndpoints[deviceID] = result.endpoint
            nextDevices[deviceID] = SharedDevice(
                id: deviceID,
                name: name,
                isTrusted: trustedDeviceIDs.contains(deviceID),
                lastSeenAt: Date()
            )
        }

        endpointsByDeviceID = nextEndpoints
        devicesByID = nextDevices
        notifyDevicesChanged()
    }

    private func send(_ message: LANMessage, to deviceID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let endpoint = self.endpointsByDeviceID[deviceID] else {
                self.reportError("目标设备当前不在线")
                return
            }

            do {
                let data = try self.encoder.encode(message)
                try self.send(data, to: endpoint)
            } catch {
                self.reportError("发送失败：\(error.localizedDescription)")
            }
        }
    }

    private func send(_ body: Data, to endpoint: NWEndpoint) throws {
        guard body.count <= maxMessageSize else {
            reportError("发送内容过大")
            return
        }

        var length = UInt32(body.count).bigEndian
        var message = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        message.append(body)

        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connection.send(content: message, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
        connection.start(queue: queue)
    }

    private func receive(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveExact(4, from: connection) { [weak self] header in
            guard let self, let header else {
                connection.cancel()
                return
            }

            let length = self.messageLength(from: header)
            guard length > 0, length <= self.maxMessageSize else {
                connection.cancel()
                return
            }

            self.receiveExact(length, from: connection) { body in
                defer { connection.cancel() }
                guard let body else { return }
                self.handleReceivedMessage(body)
            }
        }
    }

    private func receiveExact(
        _ byteCount: Int,
        from connection: NWConnection,
        accumulated: Data = Data(),
        completion: @escaping (Data?) -> Void
    ) {
        let remaining = byteCount - accumulated.count
        guard remaining > 0 else {
            completion(accumulated)
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: remaining) { [weak self] data, _, isComplete, error in
            guard let self else {
                completion(nil)
                return
            }

            if error != nil {
                completion(nil)
                return
            }

            var next = accumulated
            if let data {
                next.append(data)
            }

            if next.count >= byteCount {
                completion(next)
                return
            }

            guard !isComplete else {
                completion(nil)
                return
            }

            self.receiveExact(byteCount, from: connection, accumulated: next, completion: completion)
        }
    }

    private func handleReceivedMessage(_ body: Data) {
        do {
            let message = try decoder.decode(LANMessage.self, from: body)
            guard message.sourceDevice.id != localDevice.id else { return }

            switch message.kind {
            case .pairingRequest:
                let device = SharedDevice(
                    id: message.sourceDevice.id,
                    name: message.sourceDevice.name,
                    isTrusted: trustedDeviceIDs.contains(message.sourceDevice.id),
                    lastSeenAt: Date()
                )
                onPairingRequest?(device)
            case .clipboardItem:
                guard trustedDeviceIDs.contains(message.sourceDevice.id) else {
                    reportError("已拒绝来自未信任设备 \(message.sourceDevice.name) 的内容")
                    return
                }

                guard let payload = message.payload else { return }
                onReceivedPayload?(payload, message.sourceDevice)
            }
        } catch {
            reportError("接收内容解析失败：\(error.localizedDescription)")
        }
    }

    private func refreshTrustedState() {
        devicesByID = devicesByID.mapValues { device in
            var next = device
            next.isTrusted = trustedDeviceIDs.contains(device.id)
            return next
        }
        notifyDevicesChanged()
    }

    private func notifyDevicesChanged() {
        let devices = devicesByID.values.sorted { lhs, rhs in
            if lhs.isTrusted != rhs.isTrusted {
                return lhs.isTrusted && !rhs.isTrusted
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        DispatchQueue.main.async { [onDevicesChanged] in
            onDevicesChanged?(devices)
        }
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [onError] in
            onError?(message)
        }
    }

    private func messageLength(from data: Data) -> Int {
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { buffer in
            data.copyBytes(to: buffer)
        }
        return Int(UInt32(bigEndian: value))
    }

    private func bonjourMetadata(from result: NWBrowser.Result) -> [String: String] {
        if case let .bonjour(record) = result.metadata {
            return record.dictionary
        }

        return [:]
    }

    private func serviceName(from endpoint: NWEndpoint) -> String {
        if case let .service(name, _, _, _) = endpoint {
            return name
        }

        return "\(endpoint)"
    }

    private var serviceName: String {
        "\(localDevice.name)-\(localDevice.id.prefix(6))"
    }
}
