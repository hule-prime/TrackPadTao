// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrackPadGiaCay",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TrackPadGiaCay",
            path: "Sources/TrackPadGiaCay",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ]
)
