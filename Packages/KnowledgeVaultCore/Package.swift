// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KnowledgeVaultCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KnowledgeVaultCore", targets: ["KnowledgeVaultCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "6.0.0")),
    ],
    targets: [
        .target(
            name: "KnowledgeVaultCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/KnowledgeVaultCore"
        ),
        .testTarget(
            name: "KnowledgeVaultCoreTests",
            dependencies: ["KnowledgeVaultCore"],
            path: "Tests/KnowledgeVaultCoreTests"
        ),
    ]
)