import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys via the Carbon Event HotKey API and dispatches each
/// press to the right handler by id. A single installed event handler serves all
/// hotkeys (the previous per-instance handler couldn't tell them apart).
/// Needs no special permission — only simulating keystrokes (paste) does.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var installed = false

    private init() {}

    /// Register a hotkey. `modifiers` uses Carbon masks: cmdKey 0x0100,
    /// shiftKey 0x0200, optionKey 0x0800, controlKey 0x1000.
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_5350), id: id) // 'CLSP'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)

        guard status == noErr, let registeredRef = ref else {
            NSLog("ClipStack: failed to register global hotkey (keyCode %u, modifiers 0x%04X, error %d)",
                  keyCode, modifiers, status)
            return
        }
        handlers[id] = handler
        refs[id] = registeredRef
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let err = GetEventParameter(event,
                                            EventParamName(kEventParamDirectObject),
                                            EventParamType(typeEventHotKeyID), nil,
                                            MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                guard err == noErr else { return OSStatus(eventNotHandledErr) }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                center.dispatch(hkID.id)
                return noErr
            },
            1, &spec, selfPtr, nil
        )
        guard status == noErr else {
            NSLog("ClipStack: failed to install hotkey event handler (error %d)", status)
            return
        }
        installed = true
    }

    private func dispatch(_ id: UInt32) {
        guard let handler = handlers[id] else { return }
        if Thread.isMainThread { handler() }
        else { DispatchQueue.main.async { handler() } }
    }
}
