// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IntervalTimer",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        // The app; xtool.yml names it, since the widget extension is a library product too.
        .library(
            name: "IntervalTimer",
            targets: ["IntervalTimer"]
        ),
        // Live Activity widget extension, embedded by xtool (xtool.yml › extensions).
        .library(
            name: "IntervalTimerWidget",
            targets: ["IntervalTimerWidget"]
        ),
    ],
    targets: [
        .target(
            name: "IntervalTimer",
            dependencies: ["IntervalKit"]
        ),
        .target(
            name: "IntervalTimerWidget",
            dependencies: ["IntervalKit"],
            // xtool links extensions with Foundation's _NSExtensionMain as the entry point. That sets
            // up the extension context and then calls the program's `main` (our @main WidgetBundle),
            // but since `main` lives in this library rather than the executable, the linker drops it
            // and with it every widget. -u keeps it. (Making `_main` the entry point instead skips
            // that setup and the extension traps in ExtensionFoundation at launch.)
            linkerSettings: [.unsafeFlags(["-Xlinker", "-u", "-Xlinker", "_main"])]
        ),
        // Shared by both: Live Activity attributes, colors, time formatting.
        .target(
            name: "IntervalKit"
        ),
    ]
)
