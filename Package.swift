// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NoLidSleep",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NoLidSleep",
            path: "Sources/NoLidSleep"
        )
    ]
)
