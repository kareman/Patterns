/// Converts Unicode property data files to Swift code.

import ArgumentParser
import Foundation
import Patterns

typealias RangesAndProperties = [(range: ClosedRange<UInt32>, property: Substring)]

func unicodeProperty(fromDataFile text: String) -> RangesAndProperties {
	let hexNumber = Capture(name: "hexNumber", hexDigit+)
	let hexRange = AnyPattern("\(hexNumber)..\(hexNumber)") / hexNumber
	let rangeAndProperty: AnyPattern = "\n\(hexRange, Skip()); \(Capture(name: "property", Skip())) "

	return try! Parser(search: rangeAndProperty).matches(in: text).map { match in
		let propertyName = text[match[one: "property"]!]
		let oneOrTwoNumbers = match[multiple: "hexNumber"].map { UInt32(text[$0], radix: 16)! }
		let range = oneOrTwoNumbers.first! ... oneOrTwoNumbers.last!
		return (range, propertyName)
	}
}

extension Sequence {
	/// Passes the 2 first elements to the `transform` closure. Then passes the last element returned from `transform`,
	/// together with the next element in the source sequence, to `transform` again. And so on.
	func flatMapPairs(_ transform: (Element, Element) -> [Element]) -> [Element] {
		var result = ContiguousArray<Element>()
		result.reserveCapacity(underestimatedCount)
		var iterator = self.makeIterator()
		guard var current = iterator.next() else { return [] }

		while let next = iterator.next() {
			let transformation = transform(current, next)
			result.append(contentsOf: transformation.dropLast())
			guard let last = transformation.last ?? iterator.next() else { return Array(result) }
			current = last
		}
		result.append(current)
		return Array(result)
	}
}

/// Turns string into a proper Swift enum case name.
///
/// Removes all underscores. Unless string is all caps, lowercases the first letter.
func caseName(_ string: Substring) -> String {
	var caseName = string.replacingOccurrences(of: "_", with: "")
	let firstLetter = caseName.allSatisfy { $0.isUppercase } ? "" : caseName.removeFirst().lowercased()
	return firstLetter + caseName
}

func generateEnumAndDictionary(_ properties: [Substring: [ClosedRange<UInt32>]]) -> String {
	let propertyRanges = properties.map { propertyName, ranges in
		"\t.\(caseName(propertyName)): [\(ranges.map { "\($0)" }.joined(separator: ", "))],"
	}

	return """
	enum UnicodeProperty: String {
		case \(properties.keys.map { #"\#(caseName($0)) = "\#($0)""# }.joined(separator: ", "))
	}

	let propertyRanges: [UnicodeProperty : ContiguousArray<ClosedRange<UInt32>>] = [
	\(propertyRanges.joined(separator: "\n"))
	]
	"""
}

func generateConstants(_ properties: [Substring: [ClosedRange<UInt32>]]) -> String {
	properties.map { propertyName, ranges in
		"let \(caseName(propertyName)) = [ \(ranges.map { "\($0)" }.joined(separator: ", ")) ]"
	}.joined(separator: "\n")
}

struct Arguments: ParsableCommand {
	@Flag(name: .customLong("enumAndDictionary"), help: "Outputs an enum containing all the property names, and a dictionary with the enum as keys and arrays of ranges as values. Is the default.")
	var enumAndDictionary: Bool

	@Flag(help: "Outputs the property names as constants with arrays of ranges as values.")
	var constants: Bool

	@Argument(help: "The path to the Unicode property data file.", transform: {
		try String(contentsOfFile: $0)
	})
	var unicodeData: String

	func run() throws {
		var enumAndDictionary = self.enumAndDictionary

		if !enumAndDictionary, !constants {
			enumAndDictionary = true
		}

		let properties: [Substring: [ClosedRange<UInt32>]] =
			Dictionary(grouping: unicodeProperty(fromDataFile: unicodeData), by: \.property)
			.mapValues { (ranges: RangesAndProperties) -> [ClosedRange<UInt32>] in
				let sortedranges = ranges.map { $0.range }
					.sorted { $0.lowerBound < $1.lowerBound }

				// compact the list of ranges by joining together adjacent ranges
				return sortedranges.flatMapPairs { a, b in
					a.upperBound + 1 == b.lowerBound ? [a.lowerBound ... b.upperBound] : [a, b]
				}
			}

		if enumAndDictionary {
			print(generateEnumAndDictionary(properties))
			print()
		}
		if constants {
			print(generateConstants(properties))
			print()
		}
	}
}

Arguments.main()
