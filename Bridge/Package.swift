// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "HuixinQuotaBridge",
    platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/steipete/CodexBar.git", revision: "5bebf9a05e68059eae11d5031c7239f1aa1d49ef")],
    targets: [.executableTarget(name: "HuixinQuotaBridge", dependencies: [.product(name: "CodexBarCore", package: "CodexBar")])]
)
