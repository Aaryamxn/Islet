// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "Islet",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(
        name: "Islet", path: "Sources/Islet",
        // Embeds Info.plist so permissions work even when run straight from Xcode
        linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])]
    )]
)
