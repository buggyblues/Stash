// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Stash", targets: ["StashApp"]),
        .library(name: "StashCore", targets: ["StashCore"]),
        .library(name: "StashUI", targets: ["StashUI"])
    ],
    targets: [
        .target(
            name: "StashCore"
        ),
        .target(
            name: "StashUI",
            dependencies: ["StashCore"],
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "StashApp",
            dependencies: ["StashCore", "StashUI"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "StashCoreTests",
            dependencies: ["StashCore", "StashUI", "StashApp"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
