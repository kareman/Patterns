//
//  Patterns.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

#if SwiftEngine
public typealias TextPattern = SwiftPattern
#else
public typealias TextPattern = VMPattern
#endif

public struct Skip: VMPattern, RegexConvertible {
	public let repeatedPattern: TextPattern?
	public let description: String
	public var regex: String {
		return repeatedPattern.map { "(?:\(($0 as! RegexConvertible).regex))*?" } ?? ".*?"
	}

	public init(whileRepeating repeatedPattern: TextPattern? = nil) {
		self.repeatedPattern = repeatedPattern?.repeat(0...)
		self.description = "\(repeatedPattern.map(String.init(describing:)) ?? "")*"
	}

	public func createInstructions() -> [Instruction] {
		assert(repeatedPattern == nil)
		return [.split(first: 1, second: 3),
		        .any,
		        .jump(relative: -2)]
	}
}

public struct Capture: VMPattern, RegexConvertible {
	public func createInstructions() -> [Instruction] {
		fatalError()
	}

	public var regex: String {
		let capturedRegex = patterns.map { ($0 as! RegexConvertible).regex }.joined()
		return name.map { "(?<\($0)>\(capturedRegex))" } ?? "(\(capturedRegex))"
	}

	public var description: String = "CAPTURE" // TODO: proper description
	public let name: String?
	public let patterns: [TextPattern]

	public init(name: String? = nil, _ patterns: TextPattern...) {
		self.patterns = patterns
		self.name = name
	}

	public struct Start: VMPattern, RegexConvertible {
		public func createInstructions() -> [Instruction] {
			fatalError()
		}

		public var description: String { return "[" }
		public var regex = "("
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}
	}

	public struct End: VMPattern, RegexConvertible {
		public func createInstructions() -> [Instruction] {
			fatalError()
		}

		public var description: String { return "]" }
		public var regex = ")"

		public init() {}
	}
}

protocol Matcher: class {
	func match(in input: Patterns.Input, at startindex: Patterns.Input.Index) -> Patterns.Match?
	func match(in input: Patterns.Input, from startIndex: Patterns.Input.Index) -> Patterns.Match?
}

public struct Patterns: VMPattern, RegexConvertible {
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

	let series: [TextPattern]
	public let description: String
	#if SwiftEngine
	let matcher: PatternsEngine
	#else
	let matcher: VMBacktrackEngine
	#endif

	public var regex: String {
		return series.map { ($0 as! RegexConvertible).regex }.joined()
	}

	public init(verify series: [TextPattern?]) throws {
		self.series = series.compactMap { $0 }.flattenPatterns()
		if series.isEmpty || (series.filter { $0 is Capture.Start || $0 is Capture.End }.count > 2) {
			throw InitError.invalid(self.series.array())
		}

		#if SwiftEngine
		self.matcher = try PatternsEngine(self.series)
		#else
		self.matcher = try VMBacktrackEngine(self.series)
		#endif
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

	public func ranges<S: StringProtocol>(in input: S, from startindex: Input.Index? = nil)
		-> AnySequence<ParsedRange> where S.SubSequence == Input {
		return AnySequence(matches(in: input, from: startindex).lazy.map(\.range))
	}

	public func appending(_ pattern: TextPattern) throws -> Patterns {
		return try Patterns(verify: self.series + [pattern])
	}

	public func createInstructions() -> [Instruction] {
		return series.flatMap { $0.createInstructions() }
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
		return matcher.match(in: input, at: startindex)
	}

	internal func match(in input: Input, from startIndex: Input.Index) -> Match? {
		return matcher.match(in: input, from: startIndex)
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
