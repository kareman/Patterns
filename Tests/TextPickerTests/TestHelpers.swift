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
	func assertParseAll(_ pattern: Patterns, input: String, result: [String],
	                    file: StaticString = #file, line: UInt = #line) {
		let parsed = pattern.parseAll(input).map { String(input[$0]) }
		XCTAssertEqual(parsed, result, "\nThe differences are: \n" + parsed.difference(from: result).joined(separator: "\n"), file: file, line: line)
		XCTAssertEqual(parsed, result, "\nThe differences are: \n" + parsed.difference(from: result).sorted().joined(separator: "\n"), file: file, line: line)
	}

	func assertParseAll(_ pattern: TextPattern, input: String, result: String? = nil, count: Int,
	                    file: StaticString = #file, line: UInt = #line) {
		do {
			let pattern = try (pattern as? Patterns) ?? Patterns(pattern)
			if let result = result {
				assertParseAll(pattern, input: input, result: Array(repeating: result, count: count), file: file, line: line)
				return
			}
			let parsed = pattern.parseAll(input)
			XCTAssertEqual(parsed.count, count, "Incorrect count.", file: file, line: line)
		} catch {
			XCTFail("\(error)", file: file, line: line)
		}
	}

	fileprivate func processMarkers(_ string: String, marker: Character = "|") -> (String, [String.Index]) {
		var indices = [String.Index]()
		var string = string

		while var i = string.firstIndex(of: marker) {
			string.remove(preservingIndex: &i)
			indices.append(i)
		}
		return (string, indices)
	}

	func assertParseMarkers(_ pattern: Patterns, input: String,
	                        file: StaticString = #file, line: UInt = #line) {
		let (string, correct) = processMarkers(input)
		let parsedRanges = pattern.parseAll(string)
		XCTAssert(parsedRanges.allSatisfy { $0.isEmpty }, "Not all results are empty ranges",
		          file: file, line: line)
		let parsed = parsedRanges.map { $0.lowerBound }
		let notParsed = Set(correct).subtracting(parsed).sorted()
		if !notParsed.isEmpty {
			XCTFail("\nThese positions were not parsed:\n" + string.underlineIndices(notParsed),
			        file: file, line: line)
		}
		let incorrectlyParsed = Set(parsed).subtracting(correct).sorted()
		if !incorrectlyParsed.isEmpty {
			XCTFail("\nThese positions were incorrectly parsed:\n" + string.underlineIndices(incorrectlyParsed),
			        file: file, line: line)
		}
	}

	func assertCaptures(_ pattern: Patterns, input: String, result: [[String]],
	                    file: StaticString = #file, line: UInt = #line) {
		let matches = Array(pattern.matches(in: input))
		let output = matches.map { match in match.captures.map { String(input[$0]) } }
		XCTAssertEqual(output, result, file: file, line: line)
	}
}

extension RangeReplaceableCollection where Self: BidirectionalCollection {
	@discardableResult mutating func remove(preservingIndex i: inout Self.Index) -> Self.Element {
		guard i != startIndex else {
			defer { i = startIndex }
			return remove(at: i)
		}
		let before = self.index(before: i)
		defer { i = index(after: before) }
		return remove(at: i)
	}
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}

extension StringProtocol where Index == String.Index {
	func underlineIndices(_ indices: [Index]) -> String {
		let marker: Character = "\u{0332}"
		var result = String(self)
		for index in indices.reversed() {
			if index == endIndex {
				result.append(" \(marker)")
				break
			}
			result.insert(marker, at: result.index(after: index))
		}
		return result
	}
}
