//
//  Patterns.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 23/10/2018.
//

public struct Skip: TextPattern {
	public let repeatedPattern: TextPattern?
	public let description: String
	public var regex: String
	public let length: Int? = nil

	public init(whileRepeating repeatedPattern: TextPattern? = nil) {
		self.repeatedPattern = repeatedPattern?.repeat(min: 0)
		self.description = "\(repeatedPattern.map(String.init(describing:)) ?? "")*"
		self.regex = repeatedPattern.map { _ in "NOT IMPLEMENTED" } ?? ".*?"
	}

	public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_ input: TextPattern.Input, from startindex: TextPattern.Input.Index) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>)
		throws -> Patterns.Patternette {
			let maybeStoreBound = Bound.getBoundHandler(&remainingPatterns)

			guard let next = remainingPatterns.first else {
				return ({ (input, index, bounds: inout ContiguousArray<Input.Index>) in
					maybeStoreBound(input.endIndex, &bounds)
					return index ..< input.endIndex
				}, description + " (to the end)")
			}
			guard !(next is Skip) else {
				throw Patterns.InitError.message("Cannot have 2 Skip in a row.")
			}

			return ({ (input, index, bounds: inout ContiguousArray<Input.Index>) in
				guard let nextRange = next.parse(input, from: index) else { return nil }
				if let repeatedPattern = self.repeatedPattern {
					guard repeatedPattern.parse(input[index ..< nextRange.lowerBound], at: index)?.upperBound == nextRange.lowerBound else { return nil }
				}
				maybeStoreBound(nextRange.lowerBound, &bounds)
				return index ..< nextRange.lowerBound
			}, description)
	}
}

public struct Bound: TextPattern {
	public var description: String { return "|" }
	public var regex = "()"
	public let length: Int? = 0

	public init() { }

	public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_ input: TextPattern.Input, from startindex: TextPattern.Input.Index) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>) -> Patterns.Patternette {
		return ({ (_: Input, index: Input.Index, bounds: inout ContiguousArray<Input.Index>) in
			bounds.append(index)
			return index ..< index
		}, description)
	}

	static func getBoundHandler(_ remainingPatterns: inout ArraySlice<TextPattern>)
		-> (Input.Index, inout ContiguousArray<Input.Index>) -> Void {
			return remainingPatterns.first is Bound
				? { remainingPatterns.removeFirst(); return { $1.append($0) } }()
				: { _, _ in }
	}
}

public struct Patterns: TextPattern {
	public enum InitError: Error, CustomStringConvertible {
		case invalid([TextPattern])
		case message(String)

		public var description: String {
			switch self {
			case let .invalid(parsers):
				return "Invalid series of parsers: \(parsers)"
			case let .message(string):
				return string
			}
		}
	}

	public let series: Array<TextPattern>
	public var regex: String {
		return series.map((\TextPattern.regex).toFunc).joined()
	}

	public var length: Int? {
		let lengths = series.compactMap((\TextPattern.length).toFunc)
		return lengths.count == series.count ? lengths.reduce(0, +) : nil
	}

	public typealias Patternette =
		(parser: (Input, Input.Index, inout ContiguousArray<Input.Index>) -> ParsedRange?, description: String)
	private let patternettes: [Patternette]
	private let parserFrom: TextPattern?

	public let description: String

	private static func createPatternettes(_ parsers: Array<TextPattern>) throws -> [Patternette] {
		var remainingPatterns = parsers[...]
		var result = [Patternette]()
		while let nextPattern = remainingPatterns.popFirst() {
			if !(nextPattern is Bound), nextPattern.length == 0, let first = remainingPatterns.first {
				if type(of: nextPattern) == type(of: first) {
					throw Patterns.InitError.message("Cannot have 2 \(type(of: nextPattern)) in a row, as they will always parse the same position.") }
				if let second = remainingPatterns.second,
					type(of: nextPattern) == type(of: second),
					first.length == 0 || (first as? Skip)?.repeatedPattern == nil {
					throw Patterns.InitError.message("Cannot have 2 \(type(of: nextPattern)) with a \(first) in between, as they will always parse the same position.")
				}
			}
			result.append(try nextPattern._prepForPatterns(remainingPatterns: &remainingPatterns))
		}
		return result
	}

	public init(_ series: [TextPattern?]) throws {
		self.series = series.compactMap { $0 }.flattenPatterns()
		if series.isEmpty || (series.filter({ $0 is Bound }).count > 2) {
			throw InitError.invalid(self.series.array())
		}

		self.patternettes = try Patterns.createPatternettes(self.series)

		// find first parseable parser 'parserFrom', if there is no Skip parser before it use it in Self.parse(_:from:):
		let parserFromIndex = self.series.firstIndex(where: { !($0 is Skip || $0 is Bound) })!
		let parserFrom = self.series[parserFromIndex]
		let firstSkipIndex = self.series.firstIndex(where: { $0 is Skip })
		self.parserFrom = (firstSkipIndex.map { $0 < parserFromIndex } ?? false) ? nil : (parserFrom as? Patterns)?.parserFrom ?? parserFrom
		self.description = self.series.map(String.init(describing:)).joined(separator: " ")
	}

	public init(_ series: TextPattern?...) throws {
		try self.init(series)
	}

	public func parse(_ input: Input, at startindex: Input.Index) -> ParsedRange? {
		var n: ParsedRange?
		return parse(input, at: startindex, wholeRange: &n)
	}

	public func parse(_ input: Input, at startindex: Input.Index, wholeRange: inout ParsedRange?) -> ParsedRange? {
		var index = startindex
		var boundIndices = ContiguousArray<TextPattern.Input.Index>()

		for parserette in patternettes {
			guard let range = parserette.parser(input, index, &boundIndices) else { return nil }
			index = range.upperBound
		}

		if !boundIndices.isEmpty {
			wholeRange = startindex ..< index
		}
		return boundIndices.first.map { $0 ..< boundIndices.last! } ?? startindex ..< index
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		var n: ParsedRange?
		return parse(input, from: startIndex, wholeRange: &n)
	}

	public func parse(_ input: Input, from startIndex: Input.Index, wholeRange: inout ParsedRange?) -> ParsedRange? {
		guard let parserFrom = parserFrom else { return self.parse(input, at: startIndex, wholeRange: &wholeRange) }
		var index = startIndex
		while index <= input.endIndex {
			guard let fromIndex = parserFrom.parse(input, from: index)?.lowerBound else { return nil }
			if let range = self.parse(input, at: fromIndex, wholeRange: &wholeRange) {
				return range
			}
			guard fromIndex != input.endIndex else { return nil }
			index = input.index(after: fromIndex)
		}
		return nil
	}

	public func appending(_ parser: TextPattern) throws -> Patterns {
		return try Patterns(self.series + [parser])
	}
}

public extension Patterns {
	struct Match {
		public let fullRange: ParsedRange
		public let marks: [Input.Index]

		public var range: ParsedRange {
			return marks.isEmpty ? fullRange : marks.first! ..< marks.last!
		}

		fileprivate init(fullRange: ParsedRange?, partialRange: ParsedRange) {
			self.fullRange = fullRange ?? partialRange
			if let _ = fullRange {
				if partialRange.isEmpty {
					self.marks = [partialRange.lowerBound]
				} else {
					self.marks = [partialRange.lowerBound, partialRange.upperBound]
				}
			} else {
				self.marks = [Input.Index]()
			}
		}
	}

	func matches(in input: Input, from startindex: Input.Index? = nil)
		-> UnfoldSequence<Match, Input.Index> {
		var previousRange: ParsedRange?
		return sequence(state: startindex ?? input.startIndex, next: { (index: inout Input.Index) in
			var fullRange: ParsedRange?
			guard let range = self.parse(input, from: index, wholeRange: &fullRange),
				range != previousRange else { return nil }
			previousRange = range
			/// index = (fullRange?.isEmpty ?? true && range.isEmpty && range.upperBound != input.endIndex)
			index = (range.isEmpty && range.upperBound != input.endIndex)
				? input.index(after: range.upperBound) : range.upperBound
			return Match(fullRange: fullRange, partialRange: range)
		})
	}

	func matches(in input: String, from startindex: Input.Index? = nil)
		-> UnfoldSequence<Match, Input.Index> {
		return matches(in: input[...], from: startindex)
	}
}

fileprivate extension Sequence where Element == TextPattern {
	func flattenPatterns() -> [TextPattern] {
		return self.flatMap { (parser: TextPattern) -> [TextPattern] in
			if let series = parser as? Patterns, !series.series.contains(where: { $0 is Bound }) {
				return series.series.array()
			}
			return [parser]
		}
	}
}

extension Patterns: CustomDebugStringConvertible {
	public var debugDescription: String {
		return self.description
	}
}
