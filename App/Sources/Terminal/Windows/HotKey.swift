import AppKit
import Carbon.HIToolbox

/// A global shortcut through Carbon's RegisterEventHotKey: works from any app
/// and needs no Accessibility permission (unlike an event tap).
///
/// Carbon hot keys use physical key codes, so punctuation keys (`\`, `` ` ``,
/// `[`…) are looked up in the current keyboard layout: on a French layout
/// `\` is not on the US key. The owner re-registers when the layout changes
/// (see `HotKey.onLayoutChange`).
final class HotKey {
    private var ref: EventHotKeyRef?
    private static var handlerInstalled = false
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    /// Why the last registration failed, for the log.
    static var lastError: String?

    /// `spec` looks like "cmd+shift+backslash", "option+space", "ctrl+`".
    init?(spec: String, action: @escaping () -> Void) {
        guard let (keyCode, mods) = HotKey.parse(spec) else {
            HotKey.lastError = "unknown key in \"\(spec)\""
            return nil
        }
        HotKey.installHandler()
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.actions[id] = action
        let hotKeyID = EventHotKeyID(signature: OSType(0x5452_4D4C), id: id) // "TRML"
        let status = RegisterEventHotKey(keyCode, mods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        Debug.log("hotkey \(spec): key code \(keyCode), modifiers \(mods), status \(status)")
        guard status == noErr else {
            // eventHotKeyExistsErr (-9878): another app already owns this shortcut.
            HotKey.lastError = status == OSStatus(eventHotKeyExistsErr)
                ? "\"\(spec)\" is already used by another app" : "RegisterEventHotKey failed (\(status))"
            HotKey.actions[id] = nil
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.actions[id] = nil
    }

    /// Calls `body` whenever the user switches keyboard layout.
    static func onLayoutChange(_ body: @escaping () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { _ in body() }
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            if let action = HotKey.actions[hk.id] { DispatchQueue.main.async(execute: action) }
            return noErr
        }, 1, &spec, nil, nil)
        Debug.log("hotkey handler installed: status \(status)")
    }

    static func parse(_ spec: String) -> (UInt32, UInt32)? {
        var mods: UInt32 = 0
        var key: UInt32?
        // "+" itself can't be a key here; "plus" can.
        for raw in spec.lowercased().split(separator: "+") {
            let part = raw.trimmingCharacters(in: .whitespaces)
            switch part {
            case "cmd", "command", "super": mods |= UInt32(cmdKey)
            case "opt", "option", "alt": mods |= UInt32(optionKey)
            case "ctrl", "control": mods |= UInt32(controlKey)
            case "shift": mods |= UInt32(shiftKey)
            default: key = keyCode(for: part)
            }
        }
        guard let key else { return nil }
        return (key, mods)
    }

    /// Named keys first, then the character in the current layout, then the US position.
    static func keyCode(for name: String) -> UInt32? {
        if let code = namedKeys[name] { return code }
        let char = punctuationNames[name] ?? name
        guard char.count == 1 else { return nil }
        if let code = layoutKeyCodes()[char] { return code }
        return usKeyCodes[char]
    }

    /// Character → key code in the current keyboard layout (no modifiers).
    static func layoutKeyCodes() -> [String: UInt32] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var map: [String: UInt32] = [:]
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for code in UInt16(0)..<128 {
                var dead: UInt32 = 0
                var chars = [UniChar](repeating: 0, count: 4)
                var len = 0
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                                            OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &len, &chars)
                guard status == noErr, len == 1 else { continue }
                let s = String(utf16CodeUnits: chars, count: len).lowercased()
                if map[s] == nil { map[s] = UInt32(code) }
            }
        }
        return map
    }

    private static let namedKeys: [String: UInt32] = [
        "space": UInt32(kVK_Space), "return": UInt32(kVK_Return), "enter": UInt32(kVK_Return),
        "tab": UInt32(kVK_Tab), "escape": UInt32(kVK_Escape), "esc": UInt32(kVK_Escape),
        "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3), "f4": UInt32(kVK_F4),
        "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6), "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8),
        "f9": UInt32(kVK_F9), "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
    ]

    private static let punctuationNames: [String: String] = [
        "backslash": "\\", "grave": "`", "backtick": "`", "minus": "-", "equal": "=", "plus": "=",
        "semicolon": ";", "quote": "'", "comma": ",", "period": ".", "slash": "/",
        "leftbracket": "[", "rightbracket": "]",
    ]

    private static let usKeyCodes: [String: UInt32] = {
        var m: [String: UInt32] = [
            "space": UInt32(kVK_Space), "return": UInt32(kVK_Return), "enter": UInt32(kVK_Return),
            "tab": UInt32(kVK_Tab), "escape": UInt32(kVK_Escape), "esc": UInt32(kVK_Escape),
            "`": UInt32(kVK_ANSI_Grave), "grave": UInt32(kVK_ANSI_Grave), "backtick": UInt32(kVK_ANSI_Grave),
            "-": UInt32(kVK_ANSI_Minus), "=": UInt32(kVK_ANSI_Equal), ";": UInt32(kVK_ANSI_Semicolon),
            "'": UInt32(kVK_ANSI_Quote), ",": UInt32(kVK_ANSI_Comma), ".": UInt32(kVK_ANSI_Period),
            "/": UInt32(kVK_ANSI_Slash), "\\": UInt32(kVK_ANSI_Backslash),
            "[": UInt32(kVK_ANSI_LeftBracket), "]": UInt32(kVK_ANSI_RightBracket),
            "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3), "f4": UInt32(kVK_F4),
            "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6), "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8),
            "f9": UInt32(kVK_F9), "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
        ]
        let letters: [(String, Int)] = [
            ("a", kVK_ANSI_A), ("b", kVK_ANSI_B), ("c", kVK_ANSI_C), ("d", kVK_ANSI_D), ("e", kVK_ANSI_E),
            ("f", kVK_ANSI_F), ("g", kVK_ANSI_G), ("h", kVK_ANSI_H), ("i", kVK_ANSI_I), ("j", kVK_ANSI_J),
            ("k", kVK_ANSI_K), ("l", kVK_ANSI_L), ("m", kVK_ANSI_M), ("n", kVK_ANSI_N), ("o", kVK_ANSI_O),
            ("p", kVK_ANSI_P), ("q", kVK_ANSI_Q), ("r", kVK_ANSI_R), ("s", kVK_ANSI_S), ("t", kVK_ANSI_T),
            ("u", kVK_ANSI_U), ("v", kVK_ANSI_V), ("w", kVK_ANSI_W), ("x", kVK_ANSI_X), ("y", kVK_ANSI_Y),
            ("z", kVK_ANSI_Z), ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3),
            ("4", kVK_ANSI_4), ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7), ("8", kVK_ANSI_8),
            ("9", kVK_ANSI_9),
        ]
        for (k, v) in letters { m[k] = UInt32(v) }
        return m
    }()
}
