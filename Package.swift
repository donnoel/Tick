// swift-tools-version: 6.2
import PackageDescription

// The iOS app/widget compile these same sources directly. ProjectPilot imports
// them as TickCore, so the wire format and merge rules have one implementation.
let package = Package(
    name: "TickCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.library(name: "TickCore", targets: ["TickCore"])],
    targets: [
        .target(name: "TickCore", path: "Tick/WidgetSupport", exclude: [
            "TickAccessoryWidgetContent.swift", "TickCloudSyncStore.swift",
            "TickKeyValueStore.swift", "TickSharedStorage.swift",
            "TickStorageFileEnvelope.swift", "TickWidgetActionStore.swift",
            "TickWidgetICloudSyncStore.swift", "TickWidgetSnapshot.swift"
        ], sources: ["TickWidgetStorageSnapshot.swift", "TickCloudMerge.swift",
                     "TickCloudTransport.swift", "TickTimerMutation.swift"]),
        .testTarget(name: "TickCoreTests", dependencies: ["TickCore"], path: "TickCoreTests")
    ]
)
