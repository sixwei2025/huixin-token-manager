// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "HuixinQuotaBridge",
    platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/steipete/CodexBar.git", revision: "5dd48cab770a326691b25a124d37ffee12c5f7ac")],
    targets: [.executableTarget(name: "HuixinQuotaBridge", dependencies: [.product(name: "CodexBarCore", package: "CodexBar")])]
)
