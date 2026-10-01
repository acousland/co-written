// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoWritten",
    platforms: [.macOS(.v14)],
    products: [.library(name: "CoWrittenCore", targets: ["CoWrittenCore"]),
               .executable(name: "CoWrittenMac", targets: ["CoWrittenMac"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.10.0")],
    targets: [
        .target(name: "CoWrittenCore"),
        .executableTarget(name: "CoWrittenMac", dependencies: ["CoWrittenCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "CoWrittenCoreTests", dependencies: ["CoWrittenCore"]),
        .testTarget(name: "CoWrittenMacTests", dependencies: ["CoWrittenMac"])
    ]
)
