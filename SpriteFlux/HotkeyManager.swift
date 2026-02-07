import Cocoa
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    private static let signature = OSType(0x4D564D54) // "MVMT"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var eventHandlerUPP: EventHandlerUPP?

    var onHotkey: (() -> Void)?

    func register() {
        unregister()

        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: 1)
        let modifierFlags: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_M)

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

        withUnsafePointer(to: &eventSpec) { specPtr in
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
            keyCode,
            modifierFlags,
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
