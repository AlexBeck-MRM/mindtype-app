// swift-tools-version: 5.9
/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   S W I F T   P A C K A G E  ░░░░░░░░░  ║
  ║                                                              ║
  ║   Apple-native typing intelligence with on-device LM.       ║
  ║   Three-stage pipeline: Noise → Context → Tone              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Swift Package for MindType core + UI
  • WHY  ▸ Native performance on Apple Silicon
  • HOW  ▸ Mock LM for demo, extensible to llama.cpp/Core ML
*/

import PackageDescription

let package = Package(
    name: "MindType",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MindTypeCore",
            targets: ["MindTypeCore"]
        ),
        .library(
            name: "MindTypeUI",
            targets: ["MindTypeUI"]
        ),
        .executable(
            name: "MindTypeDemo",
            targets: ["MindTypeDemo"]
        ),
    ],
    dependencies: [
        // Future: Add llama.cpp for real inference
        // .package(url: "https://github.com/ggerganov/llama.cpp", branch: "master"),
    ],
    targets: [
        .target(
            name: "MindTypeCore",
            dependencies: [],
            path: "Sources/MindTypeCore"
        ),
        .target(
            name: "MindTypeUI",
            dependencies: ["MindTypeCore"],
            path: "Sources/MindTypeUI"
        ),
        .executableTarget(
            name: "MindTypeDemo",
            dependencies: ["MindTypeCore"],
            path: "Sources/MindTypeDemo"
        ),
        .testTarget(
            name: "MindTypeCoreTests",
            dependencies: ["MindTypeCore"],
            path: "Tests/MindTypeCoreTests"
        ),
    ]
)

