// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Branchlet",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "Branchlet", targets: ["Branchlet"])],
    targets: [
        .target(name: "BranchletCore"),
        .executableTarget(name: "Branchlet", dependencies: ["BranchletCore"]),
        .testTarget(name: "BranchletCoreTests", dependencies: ["BranchletCore"]),
    ]
)
