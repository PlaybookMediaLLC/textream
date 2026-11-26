// swift-tools-version:5.9
// Speech-tracking benchmark (see PLAN.md). Build and run it through `go run run.go`.
//
// Sources/bench/Shared and Sources/bench/LocalSpeechEngine.swift are symlinks to the
// shipping app code, so the benchmark always measures what ships.
import Foundation
import PackageDescription

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
    name: "SpeechTrackingBench",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../Textream/Vendor/TranscribeCpp")],
    targets: [
        .executableTarget(
            name: "bench",
            dependencies: [.product(name: "TranscribeCpp", package: "TranscribeCpp")],
            linkerSettings: [
                // Lets macOS grant the binary speech-recognition access (record-audio).
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                              "-Xlinker", "\(here)/Info.plist"]),
            ]
        ),
    ]
)
