// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMonitors",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "ClaudeMonitor",
            path: "macos",
            exclude: ["Info.plist", "icon.svg"]
        )
    ]
)
