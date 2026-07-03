// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ClipboardX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardX", targets: ["ClipboardX"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardX",
            path: "Sources/ClipboardX",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
