import AppKit
import Carbon.HIToolbox

/// A global shortcut through Carbon's RegisterEventHotKey: works from any app
/// and needs no Accessibility permission (unlike an event tap).
final class HotKey {
    private var ref: EventHotKeyRef?
    private static var handlerInstalled = false
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    /// `spec` looks like "option+space", "cmd+shift+t", "ctrl+`".
    init?(spec: String, action: @escaping () -> Void) {
        guard let (keyCode, mods) = HotKey.parse(spec) else { return nil }
        HotKey.installHandler()
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.actions[id] = action
        let hotKeyID = EventHotKeyID(signature: OSType(0x5452_4D4C), id: id) // "TRML"
        let status = RegisterEventHotKey(keyCode, mods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else {
            HotKey.actions[id] = nil
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.actions[id] = nil
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            if let action = HotKey.actions[hk.id] { DispatchQueue.main.async(execute: action) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    static func parse(_ spec: String) -> (UInt32, UInt32)? {
        var mods: UInt32 = 0
        var key: UInt32?
        for raw in spec.lowercased().split(separator: "+") {
            let part = raw.trimmingCharacters(in: .whitespaces)
            switch part {
            case "cmd", "command", "super": mods |= UInt32(cmdKey)
            case "opt", "option", "alt": mods |= UInt32(optionKey)
            case "ctrl", "control": mods |= UInt32(controlKey)
            case "shift": mods |= UInt32(shiftKey)
            default: key = keyCodes[part]
            }
        }
        guard let key else { return nil }
        return (key, mods)
    }

    private static let keyCodes: [String: UInt32] = {
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
