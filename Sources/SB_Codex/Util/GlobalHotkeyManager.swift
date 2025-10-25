import Carbon
import Foundation

struct Hotkey {
    let keyCode: UInt32
    let modifiers: UInt32

    static let pauseToggle = Hotkey(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
    )
}

enum HotkeyError: Error {
    case registrationFailed(OSStatus)
    case handlerInstallFailed(OSStatus)
}

final class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var handler: (() -> Void)?

    func register(hotkey: Hotkey = .pauseToggle) throws {
        unregister()

        var hotKeyID = EventHotKeyID(signature: makeFourCharCode(string: "SBCH"), id: 1)
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &newHotKeyRef)
        guard status == noErr, let registeredRef = newHotKeyRef else {
            throw HotkeyError.registrationFailed(status)
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let statusHandler = InstallEventHandler(GetEventDispatcherTarget(), hotKeyCallback, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
        guard statusHandler == noErr else {
            throw HotkeyError.handlerInstallFailed(statusHandler)
        }

        hotKeyRef = registeredRef
    }

    func unregister() {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregister()
    }
}

private func makeFourCharCode(string: String) -> OSType {
    var result: UInt32 = 0
    for scalar in string.unicodeScalars {
        result = (result << 8) + UInt32(scalar.value)
    }
    return OSType(result)
}

private func hotKeyCallback(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handler?()
    return noErr
}
