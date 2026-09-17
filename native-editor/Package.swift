// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XLSXEditor",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "XLSXKit", targets: ["XLSXKit"]),
        .executable(name: "XLSXEditor", targets: ["XLSXEditor"]),
    ],
    targets: [
        .target(
            name: "XLSXKit",
            path: "Sources/XLSXKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The interface lives in a library so it can be driven and rendered by
        // tests without launching an app.
        .target(
            name: "XLSXEditorCore",
            dependencies: ["XLSXKit"],
            path: "Sources/XLSXEditorCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "XLSXEditor",
            dependencies: ["XLSXEditorCore"],
            path: "Sources/XLSXEditor",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "XLSXKitTests",
            dependencies: ["XLSXKit"],
            path: "Tests/XLSXKitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "XLSXEditorCoreTests",
            dependencies: ["XLSXEditorCore", "XLSXKit"],
            path: "Tests/XLSXEditorCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
