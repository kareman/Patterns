// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "TextPicker",
	products: [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "TextPicker",
			targets: ["TextPicker"]),
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/kareman/FootlessParser", from: "0.5.2"),
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages which this package depends on.
		.target(
			name: "TextPicker",
			dependencies: []),
		.testTarget(
			name: "TextPickerTests",
			dependencies: ["TextPicker"]),
		.target(
			name: "UnicodeBootstrap",
			dependencies: ["FootlessParser"]),
	]
)
