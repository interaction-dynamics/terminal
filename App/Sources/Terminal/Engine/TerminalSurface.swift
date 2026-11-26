import AppKit

/// What the app can do with a terminal, whatever engine draws it.
/// Everything outside Engine/ talks to terminals only through this protocol.
protocol TerminalSurface: AnyObject {
    var view: NSView { get }
    var delegate: TerminalSurfaceDelegate? { get set }

    /// Types text as if the user typed it (no paste semantics).
    func sendText(_ text: String)
    /// Sends text wrapped in bracketed paste if the program asked for it.
    func paste(_ text: String)
    /// Sends one key press (Enter, Ctrl+C, arrows…) to the program.
    func sendKey(_ key: TerminalKey)
    /// Runs a libghostty binding action by name, for example "copy_to_clipboard".
    @discardableResult func perform(_ action: String) -> Bool

    func focus()
    var hasSelection: Bool { get }
    /// Whether the window is hidden (stops rendering when occluded).
    func setOccluded(_ occluded: Bool)
    /// Ends the shell process.
    func close()
}

enum TerminalKey {
    case enter, interrupt, endOfFile, clearScreen, tab, escape
}

protocol TerminalSurfaceDelegate: AnyObject {
    func surface(_ surface: TerminalSurface, didChangeTitle title: String)
    /// OSC 7 — sent by the shell integration before every prompt.
    func surface(_ surface: TerminalSurface, didReportDirectory path: String)
    /// OSC 133;D — a command finished.
    func surface(_ surface: TerminalSurface, didFinishCommandWithExitCode code: Int?, durationMs: Int)
    func surfaceDidRingBell(_ surface: TerminalSurface)
    func surfaceDidRequestClose(_ surface: TerminalSurface, processAlive: Bool)
    /// The user typed into the terminal itself (not the smart input).
    func surfaceDidReceiveKeyInput(_ surface: TerminalSurface)
}

extension TerminalSurfaceDelegate {
    func surfaceDidRingBell(_ surface: TerminalSurface) {}
    func surfaceDidReceiveKeyInput(_ surface: TerminalSurface) {}
}

/// Options for starting the shell in a new surface.
struct SurfaceOptions {
    var workingDirectory: String?
    var environment: [String: String] = [:]
}
