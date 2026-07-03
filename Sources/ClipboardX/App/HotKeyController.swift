import Carbon
import Foundation

final class HotKeyController {
    private let hotKeySignature = OSType(0x434C5058) // CLPX
    private let hotKeyIDValue: UInt32
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let description: String
    private let onRegistrationFailure: ((String) -> Void)?
    private let onTrigger: () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(
        keyCode: UInt32 = UInt32(kVK_ANSI_V),
        modifiers: UInt32 = UInt32(optionKey),
        id: UInt32 = 1,
        description: String = "Option+V",
        onRegistrationFailure: ((String) -> Void)? = nil,
        onTrigger: @escaping () -> Void
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.hotKeyIDValue = id
        self.description = description
        self.onRegistrationFailure = onRegistrationFailure
        self.onTrigger = onTrigger
    }

    deinit {
        unregister()
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var eventHotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &eventHotKeyID
                )

                guard status == noErr else { return status }

                let controller = Unmanaged<HotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                guard eventHotKeyID.signature == controller.hotKeySignature,
                      eventHotKeyID.id == controller.hotKeyIDValue else {
                    return noErr
                }

                controller.onTrigger()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            print("ClipboardX failed to install hotkey handler: \(handlerStatus)")
            onRegistrationFailure?(failureMessage(status: handlerStatus, phase: "安装快捷键监听"))
            return
        }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIDValue)
        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyStatus != noErr {
            print("ClipboardX failed to register \(description) hotkey: \(hotKeyStatus)")
            onRegistrationFailure?(failureMessage(status: hotKeyStatus, phase: "注册快捷键"))
            unregister()
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func failureMessage(status: OSStatus, phase: String) -> String {
        if status == -9878 {
            return "\(description) 已被其他应用或另一个 ClipboardX 实例占用，无法注册。请退出旧的 ClipboardX 进程，或换一个快捷键。"
        }

        return "\(description) \(phase)失败，状态码：\(status)。"
    }
}
