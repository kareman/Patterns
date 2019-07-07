//
//  GeneralTests.swift
//  TextPickerTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

import TextPicker
import XCTest

class PerformanceTests: XCTestCase {
	func testWordBoundary() throws {
		let text = try String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / 32)
		let parser = Word.boundary

		var result = 0
		measure {
			result = parser.parseAllLazy(text, from: text.startIndex).reduce(into: 0) { c, _ in c += 1 }
		}
		print("Found \(result) word boundaries")
	}

	func testWordBoundaryRegex() throws {
		let text = try String(String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / 32))
		let parser = try NSRegularExpression(pattern: #"\b"#)

		let range = NSRange(text.startIndex ..< text.endIndex, in: text)

		var result = 0
		measure {
			result = parser.numberOfMatches(in: text, range: range)
		}
		print("Found \(result) word boundaries")
	}

	func testLine() throws {
		let text = try String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / 32)
		let pattern = try! Patterns([line.start, Bound(), Skip(), Bound(), line.end])

		var result = 0
		self.measure {
			result = pattern.parseAllLazy(text, from: text.startIndex).reduce(into: 0) { c, _ in c += 1 }
		}
		XCTAssertEqual(result, 494)
	}

	func testNotNewLine() throws {
		let text = try String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / 32)
		let pattern = try Patterns(Literal(","), Bound(),
		                           Skip(whileRepeating: newline.not),
		                           Bound(), Line.End())
		var result = 0
		self.measure {
			result = pattern.parseAllLazy(text, from: text.startIndex).reduce(into: 0) { c, _ in c += 1 }
		}
		XCTAssertEqual(result, 352)
	}
}

extension PerformanceTests {
	public static var allTests = [
		("testWordBoundary", testWordBoundary),
	]
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
