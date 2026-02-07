// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickyTodos",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "StickyTodos", targets: ["StickyTodos"])
    ],
    targets: [
        .executableTarget(
            name: "StickyTodos",
            path: "Sources/StickyTodos"
        )
    ]
)
