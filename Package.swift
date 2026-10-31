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
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            exact: "12.18.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "CSAiEMMacApp",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
            ],
            path: "Sources/CSAiEMMacApp",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "CSAiEMMacAppTests",
            dependencies: ["CSAiEMMacApp"],
            path: "Tests/CSAiEMMacAppTests"
        ),
    ]
)
