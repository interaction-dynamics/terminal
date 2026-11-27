import AppKit
import CryptoKit

/// Update settings (specs/10-updates.md). Tune here.
enum UpdateTuning {
    static let repository = "interaction-dynamics/terminal"
    /// At launch (if the last check is older than this) and then on this interval.
    static let checkInterval: TimeInterval = 24 * 60 * 60
    static let appName = "Terminal"
    static let notesLimit = 600

    /// GitHub's latest-release endpoint. `TERMINAL_UPDATE_URL` points it at a local
    /// server to test the whole update flow without publishing anything.
    static var latestReleaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["TERMINAL_UPDATE_URL"], let url = URL(string: override) { return url }
        return URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }
}

/// A GitHub release the updater can install.
struct Release: Equatable {
    let version: String
    let notes: String
    let zipURL: URL
    let signatureURL: URL

    /// Reads GitHub's "latest release" JSON. Nil when the release has no
    /// `Terminal-<version>.zip` and `.zip.sig` pair (nothing to install).
    static func parse(_ data: Data) throws -> Release? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return nil }
        if json["draft"] as? Bool == true || json["prerelease"] as? Bool == true { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let assets = (json["assets"] as? [[String: Any]]) ?? []
        func url(named name: String) -> URL? {
            assets.first { $0["name"] as? String == name }
                .flatMap { $0["browser_download_url"] as? String }
                .flatMap(URL.init(string:))
        }
        let zip = "\(UpdateTuning.appName)-\(version).zip"
        guard let zipURL = url(named: zip), let sigURL = url(named: zip + ".sig") else { return nil }
        return Release(version: version, notes: (json["body"] as? String) ?? "", zipURL: zipURL, signatureURL: sigURL)
    }
}

enum Version {
    /// `0.10.0` > `0.9.3`. Missing parts count as 0; anything after `-` is ignored.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            let core = v.split(separator: "-", maxSplits: 1).first.map(String.init) ?? v
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

enum UpdateError: LocalizedError {
    case badSignature, noApp, wrongApp, notWritable(String)

    var errorDescription: String? {
        switch self {
        case .badSignature: return "The download's signature is not valid. Nothing was installed."
        case .noApp: return "The download doesn't contain the app."
        case .wrongApp: return "The download contains a different app or version."
        case .notWritable(let path): return "Can't replace \(path). Move the app to a folder you can write to (like Applications) and try again."
        }
    }
}

/// Checks GitHub Releases, asks, then downloads, verifies, swaps the app and
/// relaunches. Only in release builds (`bun scripts/bundle.ts --version`).
/// Network and file work run off the main thread; the main thread only shows
/// the alerts.
final class Updater: NSObject {
    static let shared = Updater()

    private var timer: Timer?
    private var busy = false
    private var activationObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private static let lastCheckKey = "update.lastCheck"
    private static let skippedKey = "update.skippedVersion"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var isEnabled: Bool {
        Bundle.main.infoDictionary?["TerminalReleaseBuild"] as? Bool == true && publicKey != nil
    }

    private lazy var publicKey: Curve25519.Signing.PublicKey? = {
        guard let url = Bundle.main.url(forResource: "update-public-key", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return Self.publicKey(base64: text)
    }()

    static func publicKey(base64: String) -> Curve25519.Signing.PublicKey? {
        guard let raw = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }

    static func verify(_ data: Data, signatureBase64: String, key: Curve25519.Signing.PublicKey) -> Bool {
        guard let sig = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return key.isValidSignature(sig, for: data)
    }

    // MARK: Checking

    /// At launch: check if the last check is a day old, then once a day.
    func start() {
        guard isEnabled else { Debug.log("updates: off (not a release build)"); return }
        let last = defaults.double(forKey: Self.lastCheckKey)
        if Date().timeIntervalSince1970 - last >= UpdateTuning.checkInterval { check(userInitiated: false) }
        let t = Timer(timeInterval: UpdateTuning.checkInterval, repeats: true) { [weak self] _ in
            self?.check(userInitiated: false)
        }
        t.tolerance = 60 * 60
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// "Check for Updates…" in the app menu.
    @objc func checkFromMenu(_ sender: Any?) { check(userInitiated: true) }

    func check(userInitiated: Bool) {
        guard isEnabled else {
            if userInitiated { inform("Updates are off in this build", "Only release builds from GitHub update themselves. This one was built locally.") }
            return
        }
        guard !busy else { return }
        busy = true
        defaults.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        var request = URLRequest(url: UpdateTuning.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let result: Result<Release?, Error>
            if let error { result = .failure(error) }
            else if status == 404 { result = .success(nil) }   // no release yet
            else if let data, status == 200 { result = Result { try Release.parse(data) } }
            else { result = .failure(URLError(.badServerResponse)) }
            DispatchQueue.main.async {
                self?.busy = false
                self?.handle(result, userInitiated: userInitiated)
            }
        }.resume()
    }

    private func handle(_ result: Result<Release?, Error>, userInitiated: Bool) {
        switch result {
        case .failure(let error):
            Debug.log("updates: check failed: \(error.localizedDescription)")
            if userInitiated { inform("Couldn't check for updates", error.localizedDescription) }
        case .success(let release):
            guard let release, Version.isNewer(release.version, than: currentVersion) else {
                Debug.log("updates: up to date (\(currentVersion))")
                if userInitiated { inform("You're up to date", "\(UpdateTuning.appName) \(currentVersion) is the latest version.") }
                return
            }
            if !userInitiated, defaults.string(forKey: Self.skippedKey) == release.version { return }
            whenActive { [weak self] in self?.offer(release) }
        }
    }

    /// A background check doesn't pop an alert over another app: it waits
    /// until the user comes back to this one.
    private func whenActive(_ action: @escaping () -> Void) {
        if NSApp.isActive { action(); return }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if let o = self.activationObserver { NotificationCenter.default.removeObserver(o) }
            self.activationObserver = nil
            action()
        }
    }

    private func offer(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "\(UpdateTuning.appName) \(release.version) is available"
        var info = "You have \(currentVersion)."
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            info += "\n\n" + (notes.count > UpdateTuning.notesLimit ? String(notes.prefix(UpdateTuning.notesLimit)) + "…" : notes)
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        switch alert.runModal() {
        case .alertFirstButtonReturn: install(release)
        case .alertThirdButtonReturn: defaults.set(release.version, forKey: Self.skippedKey)
        default: break
        }
    }

    // MARK: Installing

    private func install(_ release: Release) {
        guard let key = publicKey, !busy else { return }
        busy = true
        Debug.log("updates: downloading \(release.version)")
        let fail: (Error) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                self?.busy = false
                self?.inform("The update failed", error.localizedDescription)
            }
        }
        URLSession.shared.dataTask(with: release.signatureURL) { sigData, _, error in
            guard let sigData, error == nil, let signature = String(data: sigData, encoding: .utf8) else {
                return fail(error ?? URLError(.badServerResponse))
            }
            URLSession.shared.downloadTask(with: release.zipURL) { file, _, error in
                guard let file, error == nil else { return fail(error ?? URLError(.badServerResponse)) }
                do {
                    let newApp = try Self.prepare(zip: file, signature: signature, key: key, version: release.version)
                    // The updater is a singleton: capturing it is fine.
                    DispatchQueue.main.async {
                        do { try self.replaceAndRelaunch(with: newApp) } catch { fail(error) }
                    }
                } catch { fail(error) }
            }.resume()
        }.resume()
    }

    /// Verifies the zip's signature, unzips it, and checks it is our app at the
    /// expected version. Runs on a background queue.
    static func prepare(zip: URL, signature: String, key: Curve25519.Signing.PublicKey, version: String) throws -> URL {
        let data = try Data(contentsOf: zip, options: .mappedIfSafe)
        guard verify(data, signatureBase64: signature, key: key) else { throw UpdateError.badSignature }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("terminal-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, dir.path]
        try ditto.run()
        ditto.waitUntilExit()
        let app = dir.appendingPathComponent("\(UpdateTuning.appName).app")
        guard ditto.terminationStatus == 0, let bundle = Bundle(url: app) else { throw UpdateError.noApp }
        guard bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.infoDictionary?["CFBundleShortVersionString"] as? String == version else { throw UpdateError.wrongApp }
        return app
    }

    private func replaceAndRelaunch(with newApp: URL) throws {
        let current = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
            throw UpdateError.notWritable(current.deletingLastPathComponent().path)
        }
        _ = try FileManager.default.replaceItemAt(current, withItemAt: newApp)
        Debug.log("updates: installed, relaunching")
        // Reopen the app once this process has exited.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while /bin/kill -0 \(getpid()) 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$0\"", current.path]
        try relaunch.run()
        NSApp.terminate(nil)
    }

    private func inform(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
