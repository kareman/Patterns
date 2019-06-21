
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
	return (text.split(separator: "\n"))
		.compactMap {
			try? parse(l, $0)
		}
}

do {
	let scripts = try String(contentsOf: getLocalURL(for: "Scripts.txt"))

	let result = unicodeProperty(fromDataFile: scripts)

	print(result)
} catch {
	print(error)
}
