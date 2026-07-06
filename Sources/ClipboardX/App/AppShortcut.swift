import AppKit
import Carbon
import Foundation

struct AppShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultHistory = AppShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(optionKey)
    )

    static let defaultScreenshot = AppShortcut(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: UInt32(optionKey | shiftKey)
    )

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let modifiers = AppShortcut.carbonModifiers(from: event.modifierFlags)

        guard keyCode != UInt32(kVK_Escape), modifiers != 0 else {
            return nil
        }

        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }

        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }

        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }

        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Command")
        }

        parts.append(keyName)
        return parts.joined(separator: " + ")
    }

    var menuKeyEquivalent: String {
        Self.menuKeyEquivalents[keyCode] ?? ""
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if modifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }

        if modifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }

        if modifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }

        if modifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }

        return flags
    }

    private var keyName: String {
        Self.keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let deviceFlags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0

        if deviceFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if deviceFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if deviceFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        if deviceFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return modifiers
    }

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_ForwardDelete): "Forward Delete",
        UInt32(kVK_Home): "Home",
        UInt32(kVK_End): "End",
        UInt32(kVK_PageUp): "Page Up",
        UInt32(kVK_PageDown): "Page Down",
        UInt32(kVK_LeftArrow): "Left Arrow",
        UInt32(kVK_RightArrow): "Right Arrow",
        UInt32(kVK_UpArrow): "Up Arrow",
        UInt32(kVK_DownArrow): "Down Arrow",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12"
    ]

    private static let menuKeyEquivalents: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "a",
        UInt32(kVK_ANSI_B): "b",
        UInt32(kVK_ANSI_C): "c",
        UInt32(kVK_ANSI_D): "d",
        UInt32(kVK_ANSI_E): "e",
        UInt32(kVK_ANSI_F): "f",
        UInt32(kVK_ANSI_G): "g",
        UInt32(kVK_ANSI_H): "h",
        UInt32(kVK_ANSI_I): "i",
        UInt32(kVK_ANSI_J): "j",
        UInt32(kVK_ANSI_K): "k",
        UInt32(kVK_ANSI_L): "l",
        UInt32(kVK_ANSI_M): "m",
        UInt32(kVK_ANSI_N): "n",
        UInt32(kVK_ANSI_O): "o",
        UInt32(kVK_ANSI_P): "p",
        UInt32(kVK_ANSI_Q): "q",
        UInt32(kVK_ANSI_R): "r",
        UInt32(kVK_ANSI_S): "s",
        UInt32(kVK_ANSI_T): "t",
        UInt32(kVK_ANSI_U): "u",
        UInt32(kVK_ANSI_V): "v",
        UInt32(kVK_ANSI_W): "w",
        UInt32(kVK_ANSI_X): "x",
        UInt32(kVK_ANSI_Y): "y",
        UInt32(kVK_ANSI_Z): "z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): " ",
        UInt32(kVK_Tab): "\t",
        UInt32(kVK_Return): "\r",
        UInt32(kVK_Delete): "\u{7F}",
        UInt32(kVK_Escape): "\u{1B}"
    ]
}
