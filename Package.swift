// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Branchlet",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "Branchlet", targets: ["Branchlet"])],
    targets: [
        .target(name: "BranchletCore"),
        .executableTarget(name: "Branchlet", dependencies: ["BranchletCore"], resources: [.process("Resources")]),
        .testTarget(name: "BranchletCoreTests", dependencies: ["BranchletCore"]),
    ]
)
