import Foundation

/// Launch with TERMINAL_DEBUG=1 to print shell events to stderr.
enum Debug {
    static let enabled = ProcessInfo.processInfo.environment["TERMINAL_DEBUG"] == "1"

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        FileHandle.standardError.write(Data((message() + "\n").utf8))
    }
}
