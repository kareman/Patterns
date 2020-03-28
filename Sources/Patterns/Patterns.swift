//
//  Patterns.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

public struct Skip: TextPattern {
	public let repeatedPattern: TextPattern?
	public let description: String
	public var regex: String
	public let length: Int? = nil

	public init(whileRepeating repeatedPattern: TextPattern? = nil) {
		self.repeatedPattern = repeatedPattern?.repeat(0...)
		self.description = "\(repeatedPattern.map(String.init(describing:)) ?? "")*"
		self.regex = repeatedPattern.map { _ in "NOT IMPLEMENTED" } ?? ".*?"
	}

	public func parse(_: TextPattern.Input, at _: TextPattern.Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>)
		throws -> Patterns.Patternette {
		func getBoundHandler(_ remainingPatterns: inout ArraySlice<TextPattern>)
			-> (Input, Input.Index, inout Patterns.ParseData) -> Void {
			switch remainingPatterns.first {
			case is Capture.Start, is Capture.End:
				let me = remainingPatterns.removeFirst()
				return {
					var forgetAboutIt = ArraySlice<TextPattern>()
					try! _ = me._prepForPatterns(remainingPatterns: &forgetAboutIt).pattern($0, $1, &$2)
				}
			default:
				return { _, _, _ in }
			}
		}

		let maybeStoreBound = getBoundHandler(&remainingPatterns)

		guard let next = remainingPatterns.first else {
			return ({ (input, index, bounds: inout Patterns.ParseData) in
				// TODO: remove because it's never used
				maybeStoreBound(input, input.endIndex, &bounds)
				return index ..< input.endIndex
			}, description + " (to the end)")
		}
		guard !(next is Skip) else {
			throw Patterns.InitError.message("Cannot have 2 Skip in a row.")
		}

		return ({ (input, index, bounds: inout Patterns.ParseData) in
			guard let nextRange = next.parse(input, from: index, using: &bounds) else { return nil }
			if let repeatedPattern = self.repeatedPattern {
				guard repeatedPattern.parse(input[index ..< nextRange.lowerBound], at: index, using: &bounds)?.upperBound == nextRange.lowerBound else { return nil }
			}
			maybeStoreBound(input, nextRange.lowerBound, &bounds)
			return index ..< nextRange.lowerBound
		}, description)
	}
}

public struct Capture: TextPattern {
	public var length: Int?
	public var regex: String = ""
	public var description: String = "CAPTURE" // TODO: proper description
	public let name: String?
	public let patterns: [TextPattern]

	public init(name: String? = nil, _ patterns: TextPattern...) {
		self.patterns = patterns
		self.name = name
	}

	public func parse(_: TextPattern.Input, at _: TextPattern.Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	/*
	 public func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>) throws -> Patterns.Patternette {
	 	remainingPatterns.insert(contentsOf: patterns + [Capture.End()], at: remainingPatterns.startIndex)
	 	return try Capture.Start()._prepForPatterns(remainingPatterns: &remainingPatterns)
	 }
	 */
	public struct Start: TextPattern {
		public var description: String { return "[" }
		public var regex = "("
		public let length: Int? = 0
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}

		public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
			assertionFailure("do not call this"); return nil
		}

		public func parse(_: Input, at index: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
			data.captureBeginnings.append((name, index))
			return index ..< index
		}
	}

	public struct End: TextPattern {
		public var description: String { return "]" }
		public var regex = ")"
		public let length: Int? = 0

		public init() {}

		public func parse(_: TextPattern.Input, at _: TextPattern.Input.Index) -> ParsedRange? {
			assertionFailure("do not call this"); return nil
		}

		public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index) -> ParsedRange? {
			assertionFailure("do not call this"); return nil
		}

		public func parse(_: Input, at index: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
			if let (name, begin) = data.captureBeginnings.popLast() {
				data.captures.append((name, begin ..< index))
			} else {
				data.captures.append((nil, index ..< index))
			}
			return index ..< index
		}
	}
}

public struct Patterns: TextPattern {
	public enum InitError: Error, CustomStringConvertible {
		case invalid([TextPattern])
		case message(String)

		public var description: String {
			switch self {
			case let .invalid(patterns):
				return "Invalid series of patterns: \(patterns)"
			case let .message(string):
				return string
			}
		}
	}

	public struct ParseData {
		var captureBeginnings = ContiguousArray<(name: String?, begin: Input.Index)>()
		var captures = ContiguousArray<(name: String?, range: ParsedRange)>()
	}

	public let series: [TextPattern]
	public var regex: String {
		return series.map(\.regex).joined()
	}

	public var length: Int? {
		let lengths = series.compactMap(\TextPattern.length)
		return lengths.count == series.count ? lengths.reduce(0, +) : nil
	}

	public typealias Patternette =
		(pattern: (Input, Input.Index, inout ParseData) -> ParsedRange?, description: String)
	private let patternettes: [Patternette]
	private let patternFrom: TextPattern?

	public let description: String

	private static func createPatternettes(_ patterns: [TextPattern]) throws -> [Patternette] {
		var remainingPatterns = patterns[...]
		var result = [Patternette]()
		while let nextPattern = remainingPatterns.popFirst() {
			if !(nextPattern is Capture.Start || nextPattern is Capture.End), nextPattern.length == 0, let first = remainingPatterns.first {
				if type(of: nextPattern) == type(of: first) {
					throw Patterns.InitError.message("Cannot have 2 \(type(of: nextPattern)) in a row, as they will always parse the same position.")
				}
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

	public init(verify series: [TextPattern?]) throws {
		self.series = series.compactMap { $0 }.flattenPatterns()
		if series.isEmpty || (series.filter { $0 is Capture.Start || $0 is Capture.End }.count > 2) {
			throw InitError.invalid(self.series.array())
		}

		self.patternettes = try Patterns.createPatternettes(self.series)

		// find first parseable pattern 'patternFrom', if there is no Skip pattern before it use it in Self.parse(_:from:):
		let patternFromIndex = self.series.firstIndex(where: { !($0 is Skip || $0 is Capture || $0 is Capture.Start || $0 is Capture.End) })!
		let patternFrom = self.series[patternFromIndex]
		let firstSkipIndex = self.series.firstIndex(where: { $0 is Skip })
		self.patternFrom = (firstSkipIndex.map { $0 < patternFromIndex } ?? false) ? nil : (patternFrom as? Patterns)?.patternFrom ?? patternFrom

		self.description = self.series.map(String.init(describing:)).joined(separator: " ")
	}

	public init(verify series: TextPattern?...) throws {
		try self.init(verify: series)
	}

	public init(_ series: [TextPattern?]) {
		try! self.init(verify: series)
	}

	public init(_ series: TextPattern?...) {
		self.init(series)
	}

	public func parse(_ input: Input, at startindex: Input.Index) -> ParsedRange? {
		return match(in: input, at: startindex)?.range
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		return match(in: input, from: startIndex)?.range
	}

	public func parse(_ input: Input, at startindex: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		var index = startindex
		for patternette in patternettes {
			guard let range = patternette.pattern(input, index, &data) else { return nil }
			index = range.upperBound
		}
		return startindex ..< index
	}

	public func ranges<S: StringProtocol>(in input: S, from startindex: Input.Index? = nil)
		-> AnySequence<ParsedRange> where S.SubSequence == Input {
		return AnySequence(matches(in: input, from: startindex).lazy.map(\.range))
	}

	public func appending(_ pattern: TextPattern) throws -> Patterns {
		return try Patterns(verify: self.series + [pattern])
	}
}

extension Patterns {
	public struct Match {
		public let fullRange: ParsedRange
		public let captures: [(name: String?, range: ParsedRange)]

		init(fullRange: ParsedRange, captures: [(name: String?, range: ParsedRange)]) {
			self.fullRange = fullRange
			self.captures = captures
		}

		init(fullRange: ParsedRange, data: ParseData) {
			let captures = (data.captureBeginnings.map { ($0, $1 ..< $1) } + data.captures).sorted(by: { $0.range < $1.range })
			self.init(fullRange: fullRange, captures: captures)
		}

		public var range: ParsedRange {
			return captures.isEmpty ? fullRange : captures.first!.range.lowerBound ..< captures.last!.range.upperBound
		}

		public func description(using text: String) -> String {
			return """
			fullRange: \(text[fullRange])
			captures: \(captures.map { "\($0.name ?? "")\t\t\(text[$0.range])\n" })
			"""
		}

		public subscript(one name: String) -> ParsedRange? {
			return captures.first(where: { $0.name == name })?.range
		}

		public subscript(multiple name: String) -> [ParsedRange] {
			return captures.filter { $0.name == name }.map(\.range)
		}

		public var names: Set<String> { Set(captures.compactMap(\.name)) }
	}

	internal func match(in input: Input, at startindex: Input.Index) -> Match? {
		var data = ParseData()
		var index = startindex
		for patternette in patternettes {
			guard let range = patternette.pattern(input, index, &data) else { return nil }
			index = range.upperBound
		}

		return Match(fullRange: startindex ..< index, data: data)
	}

	internal func match(in input: Input, from startIndex: Input.Index) -> Match? {
		guard let patternFrom = patternFrom else { return self.match(in: input, at: startIndex) }
		var index = startIndex
		var data = ParseData()
		while index <= input.endIndex {
			guard let fromIndex = patternFrom.parse(input, from: index, using: &data)?.lowerBound else { return nil }
			if let match = self.match(in: input, at: fromIndex) {
				return match
			}
			guard fromIndex != input.endIndex else { return nil }
			index = input.index(after: fromIndex)
		}
		return nil
	}

	public func matches<S: StringProtocol>(in input: S, from startindex: Input.Index? = nil)
		-> UnfoldSequence<Match, Input.Index> where S.SubSequence == Substring {
		let input = input[...]
		var previousRange: ParsedRange?
		return sequence(state: startindex ?? input.startIndex, next: { (index: inout Input.Index) in
			guard let match = self.match(in: input, from: index),
				match.range != previousRange else { return nil }
			let range = match.range
			previousRange = range
			index = (range.isEmpty && range.upperBound != input.endIndex)
				? input.index(after: range.upperBound) : range.upperBound
			return match
		})
	}
}

private extension Sequence where Element == TextPattern {
	func flattenPatterns() -> [TextPattern] {
		return self.flatMap { (pattern: TextPattern) -> [TextPattern] in
			if let series = (pattern as? Patterns)?.series,
				!series.contains(where: { $0 is Capture.Start || $0 is Capture.End }) {
				return series
			} else if let capture = pattern as? Capture {
				return [Capture.Start(name: capture.name)] + capture.patterns + [Capture.End()]
			}
			return [pattern]
		}
	}
}

extension Patterns: CustomDebugStringConvertible {
	public var debugDescription: String {
		return self.description
	}
}
