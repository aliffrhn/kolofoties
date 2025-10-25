// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SB_Codex",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SB_Codex",
            targets: ["SB_Codex"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SB_Codex",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
                .linkedFramework("Vision")
            ]
        )
    ]
)
