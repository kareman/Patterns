/// Converts Unicode property data files to Swift code.

import Foundation
import TextPicker

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
	let firstLetter = caseName.allSatisfy { $0.isUppercase } ? "" : caseName.removeFirst().lowercased()
	return firstLetter + caseName
}

do {
	guard CommandLine.arguments.count == 2 else {
		print("""

		Converts Unicode property data files to Swift code.

		    Usage: unicode_properties <filepath>

		""")
		exit(1)
	}
	let unicodeData = try String(contentsOfFile: CommandLine.arguments[1])
	let properties = Dictionary(grouping: unicodeProperty(fromDataFile: unicodeData), by: { $0.property })
		.mapValues { ranges -> [ClosedRange<UInt32>] in
			ranges.map { $0.range }
				.sorted { $0.lowerBound < $1.lowerBound }
				// compact the list of ranges by joining together adjacent ranges
				.flatMapPairs { a, b in
					a.upperBound + 1 == b.lowerBound ? [a.lowerBound ... b.upperBound] : [a, b]
				}
		}

	print()
	print("enum UnicodeProperty: String {")
	print("  case", properties.keys.map { #"\#(caseName($0)) = "\#($0)""# }.joined(separator: ", "))
	print("}")

	print()
	print("let propertyRanges: [UnicodeProperty : ContiguousArray<ClosedRange<UInt32>>] = [")
	properties.forEach { propertyName, ranges in
		print("  .\(caseName(propertyName)): [", ranges.map { "\($0)" }.joined(separator: ", "), "],", separator: "")
	}
	print("]")
	print()
} catch {
	print(error.localizedDescription)
	exit(Int32(error._code))
}
