import Cocoa
import Carbon

struct KeyboardShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let moveModeDefault = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_M),
        modifiers: UInt32(cmdKey | shiftKey)
    )
}

enum KeyboardShortcutFormatter {
    private static let modifierDisplayOrder: [(UInt32, String)] = [
        (UInt32(cmdKey), "Command"),
        (UInt32(optionKey), "Option"),
        (UInt32(controlKey), "Control"),
        (UInt32(shiftKey), "Shift")
    ]

    private static let modifierSymbolOrder: [(UInt32, String)] = [
        (UInt32(cmdKey), "⌘"),
        (UInt32(shiftKey), "⇧"),
        (UInt32(optionKey), "⌥"),
        (UInt32(controlKey), "⌃")
    ]

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
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_ForwardDelete): "Forward Delete",
        UInt32(kVK_Escape): "Escape",
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
        UInt32(kVK_F12): "F12",
        UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[",
        UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\",
        UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`"
    ]

    private static let symbolicKeyNames: [UInt32: String] = [
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓"
    ]

    private static let modifierOnlyKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command),
        UInt32(kVK_RightCommand),
        UInt32(kVK_Shift),
        UInt32(kVK_RightShift),
        UInt32(kVK_Option),
        UInt32(kVK_RightOption),
        UInt32(kVK_Control),
        UInt32(kVK_RightControl),
        UInt32(kVK_CapsLock),
        UInt32(kVK_Function)
    ]

    static func string(for shortcut: KeyboardShortcut) -> String {
        let modifierText = modifierDisplayOrder
            .filter { shortcut.modifiers & $0.0 != 0 }
            .map { $0.1 }
            .joined(separator: " + ")
        let keyText = keyNames[shortcut.keyCode] ?? "Key Code \(shortcut.keyCode)"

        if modifierText.isEmpty {
            return keyText
        }

        return "\(modifierText) + \(keyText)"
    }

    static func symbolicString(for shortcut: KeyboardShortcut) -> String {
        let modifierText = modifierSymbolOrder
            .filter { shortcut.modifiers & $0.0 != 0 }
            .map { $0.1 }
            .joined(separator: " ")
        let keyText = symbolicKeyNames[shortcut.keyCode] ?? keyNames[shortcut.keyCode] ?? "Key \(shortcut.keyCode)"

        if modifierText.isEmpty {
            return keyText
        }

        return "\(modifierText) \(keyText)"
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    static func isModifierOnlyKeyCode(_ keyCode: UInt32) -> Bool {
        modifierOnlyKeyCodes.contains(keyCode)
    }
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    private static let signature = OSType(0x4D564D54) // "MVMT"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var eventHandlerUPP: EventHandlerUPP?

    var onHotkey: (() -> Void)?

    func register() {
        register(shortcut: SettingsManager.shared.moveModeShortcut)
    }

    func register(shortcut: KeyboardShortcut) {
        unregister()

        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: 1)

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, userData in
            guard let event = event, let userData = userData else {
                return noErr
            }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var incomingID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &incomingID
            )

            if status == noErr,
               incomingID.signature == HotkeyManager.signature,
               incomingID.id == 1 {
                manager.onHotkey?()
            }

            return noErr
        }

        eventHandlerUPP = handler

        _ = withUnsafePointer(to: &eventSpec) { specPtr in
            InstallEventHandler(
                GetEventDispatcherTarget(),
                handler,
                1,
                specPtr,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                &eventHandler
            )
        }

        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        eventHandlerUPP = nil
    }
}
