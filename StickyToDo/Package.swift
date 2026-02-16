// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickyToDo",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "StickyToDo", targets: ["StickyToDo"])
    ],
    targets: [
        .executableTarget(
            name: "StickyToDo",
            path: "Sources/StickyToDo"
        )
    ]
)
