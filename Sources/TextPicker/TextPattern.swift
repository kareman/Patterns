//
//  Parser.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation

public typealias ParsedRange = Range<TextPattern.Input.Index>

public protocol TextPattern: CustomStringConvertible {
	typealias Input = Substring

	func parse(_ input: Input, at index: Input.Index) -> ParsedRange?
	func parse(_ input: Input, from index: Input.Index) -> ParsedRange?
	func parseAllLazy(_ input: Input, from startindex: Input.Index)
		-> UnfoldSequence<ParsedRange, Input.Index>
	func `repeat`(min: Int) -> TextPattern
	func `repeat`(min: Int, max: Int?) -> TextPattern
	func _prepForSeriesParser(remainingParsers: inout ArraySlice<TextPattern>) throws -> SeriesParser.Parserette
	/// The length this parser always parses, if it is constant
	var length: Int? { get }
	var regex: String { get }
}

public protocol TextPatternWrapper: TextPattern {
	var parser: TextPattern { get }
}

public extension TextPatternWrapper {
	func parse(_ input: Input, at index: Input.Index) -> ParsedRange? {
		return parser.parse(input, at: index)
	}

	func parse(_ input: Input, from index: Input.Index) -> ParsedRange? {
		return parser.parse(input, from: index)
	}

	func parseAllLazy(_ input: Input, from startindex: Input.Index)
		-> UnfoldSequence<ParsedRange, Input.Index> {
		return parser.parseAllLazy(input, from: startindex)
	}

	func `repeat`(min: Int) -> TextPattern {
		return parser.repeat(min: min)
	}

	var length: Int? {
		return parser.length
	}
}

extension TextPattern {
	public func parseAll(_ input: Input, from startindex: Input.Index) -> [ParsedRange] {
		return Array(parseAllLazy(input, from: startindex))
	}

	public func parseAll(_ input: String, from startindex: String.Index)
		-> [ParsedRange] {
		return parseAll(input[...], from: startindex)
	}

	public func parseAllLazy(_ input: Input, from startindex: Input.Index)
		-> UnfoldSequence<ParsedRange, Input.Index> {
			var previousRange: ParsedRange?
			return sequence(state: startindex, next: { (index: inout Input.Index) in
				guard let range = self.parse(input, from: index), range != previousRange else {
					return nil }
				previousRange = range
				index = (range.isEmpty && range.upperBound != input.endIndex)
					? input.index(after: range.upperBound) : range.upperBound
				return range
			})
	}

	public func parseAll(_ input: Input) -> [ParsedRange] {
		return parseAll(input, from: input.startIndex)
	}

	public func parseAll(_ input: String) -> [ParsedRange] {
		return parseAll(input[...])
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		var index = startIndex
		while index < input.endIndex {
			if let range = parse(input, at: index) {
				return range
			}
			input.formIndex(after: &index)
		}
		return nil
	}

	public func _prepForSeriesParser(remainingParsers: inout ArraySlice<TextPattern>) throws -> SeriesParser.Parserette {
		return ({ (input: Input, index: Input.Index, _: inout ContiguousArray<Input.Index>) in
			self.parse(input, at: index)
		}, description)
	}
}

public struct Literal: TextPattern {
	let substring: Input
	let searchCache: SearchCache<Input.Element>

	public var description: String {
		return #""\#(String(substring).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	public var regex: String {
		return NSRegularExpression.escapedPattern(for: String(substring))
	}

	public var length: Int? { return substring.count }

	public init<S: Sequence>(_ sequence: S) where S.Element == Character {
		self.substring = TextPattern.Input(sequence)
		self.searchCache = SearchCache(pattern: self.substring)
		assert(!self.substring.isEmpty, "Cannot have an empty SubstringParser.")
	}

	public init(_ substring: String) {
		self.init(substring[...])
	}

	public init(_ character: Character) {
		self.init(String(character))
	}

	public func parse(_ input: TextPattern.Input, at index: TextPattern.Input.Index) -> ParsedRange? {
		return input[index ..< input.endIndex].starts(with: substring)
			? index ..< input.index(index, offsetBy: substring.count) : nil
	}

	public func parse(_ input: Input, from index: Input.Index) -> ParsedRange? {
		return input.range(of: substring, from: index, cache: searchCache)
	}

	/*
	 public func parseAll(_ input: Input, from startindex: Input.Index) -> [ParsedRange] {
	 return input.ranges(of: input, from: startindex, cache: searchCache)
	 }
	 */
}

extension Literal: ExpressibleByStringLiteral {
	public init(stringLiteral value: StaticString) {
		self.init( String(describing: value))
	}
}

public struct OneOf: TextPattern {
	public let set: Group<Character>

	public let description: String
	public var regex: String { return set.regex }
	public let length: Int? = 1

	public init(_ set: Group<Character>) {
		self.set = set
		self.description = set.description
	}

	public init<S: Collection>(contentsOf characters: S) where S.Element == Input.Element {
		set = Group(contentsOf: characters)
		description = "OneOf(\(set.description))"
	}

	public func parse(_ input: TextPattern.Input, at index: TextPattern.Input.Index) -> ParsedRange? {
		return (index < input.endIndex && set.contains(input[index])) ? index ..< input.index(after: index) : nil
	}

	public static let alphanumeric = OneOf(Group(
		description: "alphanumeric", regex: #"(?:\p{Alphabetic}|\p{Nd})"#,
		contains: { $0.isWholeNumber || $0.isLetter }))
	public static let wholeNumber = OneOf(Group(description: "wholeNumber", regex: #"\p{Nd}"#,
		contains: (\Character.isWholeNumber).toFunc))
	public static let letter = OneOf(Group(description: "letter", regex: #"\p{Alphabetic}"#,
		contains: (\Character.isLetter).toFunc))
	public static let lowercaseLetter = OneOf(Group(description: "lowercaseLetter", regex: #"\p{Ll}"#,
		contains: (\Character.isLowercase).toFunc))
	public static let newline = OneOf(Group(description: "newline", regex: #"\p{Zl}"#,
		contains: (\Character.isNewline).toFunc))
	public static let punctuationCharacter = OneOf(Group(
		description: "punctuationCharacter", regex: #"\p{P}"#,
		contains: (\Character.isPunctuation).toFunc))
	public static let symbol = OneOf(Group(description: "symbol", regex: #"\p{S}"#,
		contains: (\Character.isSymbol).toFunc))
	public static let uppercaseLetter = OneOf(Group(description: "uppercaseLetter", regex: #"\p{Lu}"#,
		contains: (\Character.isUppercase).toFunc))
	public static let whitespaceOrNewline = OneOf(Group(
		description: "whitespaceOrNewline", regex: #"\p{White_Space}"#,
		contains: (\Character.isWhitespace).toFunc))

	public static let baseParsers: [OneOf] = [
		alphanumeric, wholeNumber, letter, lowercaseLetter, newline, punctuationCharacter, symbol,
		uppercaseLetter, whitespaceOrNewline]

	public static func parsers(for c: Character) -> [TextPattern] {
		return OneOf.baseParsers.filter { $0.set.contains(c) }
	}

	public static func parsers<S: Sequence>(for s: S) -> [TextPattern] where S.Element == Input.Element {
		return OneOf.baseParsers.filter { $0.set.contains(contentsOf: s) }
	}
}

public struct RepeatPattern: TextPattern {
	let repeatedParser: TextPattern
	let min: Int
	let max: Int?

	public var description: String {
		return "\(repeatedParser){\(min)...\(max.map(String.init) ?? "")}"
	}

	public var regex: String {
		return repeatedParser.regex + "{\(min),\(max.map(String.init(describing:)) ?? "")}"
	}

	public var length: Int? {
		return min == max ? repeatedParser.length.map { $0 * min } : nil
	}

	public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> ParsedRange? {
		var index = startindex
		for _ in 0 ..< min {
			guard let nextindex = repeatedParser.parse(input, at: index)?.upperBound else { return nil }
			index = nextindex
		}
		for _ in min ..< (max ?? Int.max) {
			guard index < input.endIndex else { return startindex ..< index }
			guard let nextindex = repeatedParser.parse(input, at: index)?.upperBound else {
				return startindex ..< index
			}
			index = nextindex
		}
		return startindex ..< index
	}

	/*
	 public func parse(_ input: Parser.Input, from startindex: Parser.Input.Index) -> ParsedRange? {
	 guard min > 0 else { return Parser.parse(self, input, at: startindex) }
	 guard let firstrange = repeatedParser.parse(input, from: startindex) else { return nil }
	 guard max > 1 else { return firstrange }
	 guard let therest = repeatedParser.repeat(min: Swift.max(0, min-1), max: max-1).parse(input, at: firstrange.upperBound) else { return nil }
	 return firstrange.lowerBound..<therest.upperBound
	 }
	 */
}

extension TextPattern {
	public func `repeat`(min: Int, max: Int?) -> TextPattern {
		assert(min >= 0 && max.map { $0 >= min } ?? true)
		return RepeatPattern(repeatedParser: self, min: min, max: max)
	}

	public func `repeat`(min: Int) -> TextPattern {
		return self.repeat(min: min, max: nil)
	}
}

public struct OrPattern: TextPattern {
	let parser1, parser2: TextPattern

	public var description: String {
		return "(\(parser1) OR \(parser2))"
	}
	public var regex: String {
		return parser1.regex + "|" + parser2.regex
	}

	public var length: Int? {
		return parser1.length == parser2.length ? parser1.length : nil
	}

	public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> ParsedRange? {
		return parser1.parse(input, at: startindex) ?? parser2.parse(input, at: startindex)
	}

	public func parse(_ input: TextPattern.Input, from startindex: TextPattern.Input.Index) -> ParsedRange? {
		let result1 = parser1.parse(input, from: startindex)
		let result2 = parser2.parse(input, from: startindex)
		if result1?.lowerBound == result2?.lowerBound { return result1 }
		return [result1, result2].compactMap { $0 }.sorted(by: <).first
	}
}

public func || (p1: TextPattern, p2: TextPattern) -> OrPattern {
	return OrPattern(parser1: p1, parser2: p2)
}

public struct BeginningOfLineParser: TextPattern {
	public init() {}

	public var description: String {
		return "BeginningOfLine"
	}
	public var regex = "^"
	public var length: Int? = 0

	public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> ParsedRange? {
		return startindex == input.startIndex || input[input.index(before: startindex)].isNewline
			? startindex ..< startindex
			: nil
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		return parse(input, at: startIndex)
			?? input[startIndex...].firstIndex(where: (\Character.isNewline).toFunc)
			.map(input.index(after:))
			.map { $0 ..< $0 }
	}
}

public struct EndOfLineParser: TextPattern {
	public init() {}

	public var description: String {
		return "EndOfLine"
	}
	public let regex = "$"
	public let length: Int? = 0

	public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> ParsedRange? {
		if startindex == input.endIndex || input[startindex].isNewline {
			return startindex ..< startindex
		}
		return nil
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		return input[startIndex...].firstIndex(where: (\Character.isNewline).toFunc).map { $0 ..< $0 }
			?? input.endIndex ..< input.endIndex
	}
	
	public func _prepForSeriesParser(remainingParsers: inout ArraySlice<TextPattern>) throws -> SeriesParser.Parserette {
		if (remainingParsers.first.map { !($0 is SeriesParser.Bound) } ?? false) {
			return ({ (input: Input, index: Input.Index, _: inout ContiguousArray<Input.Index>) in
				index == input.endIndex ? nil : self.parse(input, at: index)
			}, "EndOfLineParser (test for end)")
		}
		return ({ (input: Input, index: Input.Index, _: inout ContiguousArray<Input.Index>) in
			self.parse(input, at: index)
		}, "EndOfLineParser")
	}
}

public struct NotPattern: TextPattern {
	let parser: TextPattern
	public var description: String {
		return "!\(parser)"
	}
	public var regex: String {
		assertionFailure()
		return "NOT IMPLEMENTED"
	}
	public let length: Int? = 1

	public func parse(_ input: Input, at index: Input.Index) -> ParsedRange? {
		guard let nextIndex = input.index(index, offsetBy: 1, limitedBy: input.endIndex) else {
			return nil
		}
		return parser.parse(input, at: index) == nil ? index..<nextIndex : nil
	}
}

extension TextPattern {
	public var not: NotPattern {
		return NotPattern(parser: self)
	}
}
