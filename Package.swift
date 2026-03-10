// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CSAiEMMacApp",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "CSAiEMMacApp", targets: ["CSAiEMMacApp"]),
    ],
    targets: [
        .executableTarget(
            name: "CSAiEMMacApp",
            path: "Sources/CSAiEMMacApp"
        ),
    ]
)
