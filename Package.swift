// swift-tools-version: 6.0
// The macOS app. Open this file in Xcode, or build with `bun scripts/bundle.ts`.
// libghostty must be built first: `bun scripts/build-libghostty.ts`.

import PackageDescription

let package = Package(
    name: "Terminal",
    platforms: [.macOS(.v14)],
    targets: [
        .binaryTarget(
            name: "GhosttyKit",
            path: "Vendor/ghostty/GhosttyKit.xcframework"
        ),
        .executableTarget(
            name: "Terminal",
            dependencies: ["GhosttyKit"],
            path: "App/Sources/Terminal",
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("IOSurface"),
                .linkedFramework("JavaScriptCore"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .testTarget(
            name: "TerminalTests",
            dependencies: ["Terminal"],
            path: "App/Tests/TerminalTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
