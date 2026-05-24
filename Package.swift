// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskAnalyzer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DiskAnalyzer",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
