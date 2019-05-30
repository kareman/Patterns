// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "TextPicker",
    products: [
        .library(
            name: "TextPicker",
            targets: ["TextPicker"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TextPicker",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "TextPickerTests",
            dependencies: ["TextPicker"],
            path: "Tests"
        ),
    ]
)
