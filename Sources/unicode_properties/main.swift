/// Converts Unicode property data files to Swift code.

import Foundation
import Moderator
import Patterns

func unicodeProperty(fromDataFile text: String) -> [(range: ClosedRange<UInt32>, property: Substring)] {
	let hexNumber = Capture(name: "hexNumber", hexDigit.repeat(1...))
	let hexRange = Patterns("\(hexNumber)..\(hexNumber)") || hexNumber
	let rangeAndProperty: Patterns = "\n\(hexRange, Skip()); \(Capture(name: "property", Skip())) "

	return rangeAndProperty.matches(in: text).map { match in
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
	let firstLetter = caseName.allSatisfy(\.isUppercase) ? "" : caseName.removeFirst().lowercased()
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
	return properties.map { propertyName, ranges in
		"let \(caseName(propertyName)) = [ \(ranges.map { "\($0)" }.joined(separator: ", ")) ]"
	}.joined(separator: "\n")
}

do {
	let arguments = Moderator(description: "Converts Unicode property data files to Swift code.")
	let enumAndDictionaryArgument = arguments.add(
		.option("enumAndDictionary",
		        description: "Outputs an enum containing all the property names, and a dictionary with the enum as keys and arrays of ranges as values. Is the default."))
	let constantsArgument = arguments.add(
		.option("constants", description: "Outputs the property names as constants with arrays of ranges as values."))
	let unicodeData = arguments.add(Argument<String>.singleArgument(name: "file", description: "The path to the Unicode property data file.")
		.required(errormessage: "File path is missing.")
		.map { try String(contentsOfFile: $0) }
	)
	try arguments.parse(strict: true)

	if !enumAndDictionaryArgument.value, !constantsArgument.value {
		enumAndDictionaryArgument.value = true
	}

	let properties = Dictionary(grouping: unicodeProperty(fromDataFile: unicodeData.value), by: \.property)
		.mapValues { ranges -> [ClosedRange<UInt32>] in
			ranges.map(\.range)
				.sorted { $0.lowerBound < $1.lowerBound }
				// compact the list of ranges by joining together adjacent ranges
				.flatMapPairs { a, b in
					a.upperBound + 1 == b.lowerBound ? [a.lowerBound ... b.upperBound] : [a, b]
				}
		}

	if enumAndDictionaryArgument.value {
		print(generateEnumAndDictionary(properties))
		print()
	}
	if constantsArgument.value {
		print(generateConstants(properties))
		print()
	}
} catch let error as ArgumentError {
	print(error)
	exit(Int32(error._code))
} catch {
	print(error.localizedDescription)
	exit(Int32(error._code))
}
