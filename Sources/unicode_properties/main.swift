
import FootlessParser
import Foundation

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}

public func parse<A, S: StringProtocol>(_ p: Parser<Character, A>, _ s: S) throws -> A {
	return try (p <* eof()).parse(AnyCollection(s)).output
}

func unicodeProperty<S: StringProtocol>(fromDataFile text: S)
	-> [(range: ClosedRange<UInt32>, property: String)] {
	let hex = char(CharacterSet(charactersIn: "0" ... "9").union(CharacterSet(charactersIn: "A" ... "F")), name: "hex")
	let hex4 = { UInt32($0, radix: 16)! } <^> count(4 ... 5, hex)
	let rhex4 = curry { $0 ... $1 } <^> hex4 <* string("..") <*> hex4
	let rorhex4 = rhex4 <|> { $0 ... $0 } <^> hex4
	let v = tuple <^> rorhex4 <* oneOrMore(whitespace) <* string("; ") <*> oneOrMore(not(" "))
	let l = v <* oneOrMore(any())
	return text.split(separator: "\n").compactMap {
		try? parse(l, $0)
	}
}

extension Sequence {
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

func caseName(_ string: String) -> String {
	var caseName = string.replacingOccurrences(of:  "_", with: "")
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
		print("  .\(caseName(propertyName)): [", ranges.map {"\($0)"}.joined(separator: ", "), "],", separator: "")
	}
	print("]")
	print()
} catch {
	print(error.localizedDescription)
	exit(Int32(error._code))
}