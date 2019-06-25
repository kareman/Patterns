//
//  File.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 29.07.2018.
//

import Foundation
import TextPicker
import XCTest

extension Array where Element: Hashable {
	func difference(from other: [Element]) -> [Element] {
		let thisSet = Set(self)
		let otherSet = Set(other)
		return Array(thisSet.symmetricDifference(otherSet))
	}
}

extension XCTestCase {
	func assertParses(_ range: ParsedRange?, input: String, result: String?,
	                  file: StaticString = #file, line: UInt = #line) {
		guard let range = range else { XCTAssertNil(result, file: file, line: line); return }
		let parsed = String(input[range])
		XCTAssertEqual(parsed, result, file: file, line: line)
	}

	func assertParseAll(_ pattern: TextPattern, input: String, result: [String],
	                    file: StaticString = #file, line: UInt = #line) {
		let parsed = pattern.parseAll(input).map { String(input[$0]) }
		XCTAssertEqual(parsed, result, "\nThe differences are: \n" + parsed.difference(from: result).joined(separator: "\n"), file: file, line: line)
		XCTAssertEqual(parsed, result, "\nThe differences are: \n" + parsed.difference(from: result).sorted().joined(separator: "\n"), file: file, line: line)
	}

	func assertParseAll(_ pattern: TextPattern, input: String, result: String? = nil, count: Int,
	                    file: StaticString = #file, line: UInt = #line) {
		if let result = result {
			assertParseAll(pattern, input: input, result: Array(repeating: result, count: count), file: file, line: line)
			return
		}
		let parsed = pattern.parseAll(input)
		XCTAssertEqual(parsed.count, count, "Incorrect count.", file: file, line: line)
	}
}
