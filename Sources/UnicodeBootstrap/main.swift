
import FootlessParser
import Foundation

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}

public func parse<A, S: StringProtocol>(_ p: Parser<Character, A>, _ s: S) throws -> A {
	return try (p <* eof()).parse(AnyCollection(s)).output
}

func unicodeProperty<S: StringProtocol>(fromDataFile text: S) -> [(range: ClosedRange<UInt32>, property: String)] {
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

do {
	print([1, 2, 4, 5, 7, 9, 10].flatMapPairs { a, b in
		a + 1 == b ? [b] : [a, b]
	})
	let scripts = try String(contentsOf: getLocalURL(for: "Scripts.txt"))

	let result = unicodeProperty(fromDataFile: scripts)
	let properties = Dictionary(grouping: result, by: { $0.property })
		.mapValues { $0.map { property in property.range } }

	var common = properties["Katakana"]!
	print(common.count, common)
	common = common.flatMapPairs { a, b in
		a.upperBound + 1 == b.lowerBound ? [a.lowerBound ... b.upperBound] : [a, b]
	}
	print(common.count, common)

	// let ranges = properties.values.sorted(by: { $0.count < $1.count })

	// print(ranges)
} catch {
	print(error)
}
