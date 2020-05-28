//
//  Patterns.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

public protocol Pattern: CustomStringConvertible {
	typealias Input = String
	typealias ParsedRange = Range<Input.Index>
	typealias Instructions = ContiguousArray<Instruction<Input>> // TODO: use almost everywhere

	func createInstructions(_ instructions: inout Instructions)
	func createInstructions() -> Instructions
}

extension Pattern {
	public func createInstructions() -> Instructions {
		var instructions = Instructions()
		self.createInstructions(&instructions)
		return instructions
	}
}

public struct Parser<Input: BidirectionalCollection> where Input.Element: Equatable {
	public enum InitError: Error, CustomStringConvertible {
		case invalid([Pattern])
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

	let matcher: VMBacktrackEngine<Input>

	public init<P: Pattern>(_ pattern: P) throws where P.Input == Input {
		self.matcher = try VMBacktrackEngine(pattern)
	}

	public func ranges(in input: Input, from startindex: Input.Index? = nil)
		-> AnySequence<Range<Input.Index>> {
		return AnySequence(matches(in: input, from: startindex).lazy.map(\.range))
	}

	public struct Match {
		// TODO: replace with the end index of where pattern matched. So we can remove the outer capture from VMBacktrackEngine.init .
		public let fullRange: Range<Input.Index>
		public let captures: [(name: String?, range: Range<Input.Index>)]

		init(fullRange: Range<Input.Index>, captures: [(name: String?, range: Range<Input.Index>)]) {
			self.fullRange = fullRange
			self.captures = captures
		}

		@inlinable
		public var range: Range<Input.Index> {
			captures.isEmpty ? fullRange : captures.first!.range.lowerBound ..< captures.last!.range.upperBound
		}

		public func description(using input: Input) -> String {
			return """
			fullRange: \(input[fullRange])
			captures: \(captures.map { "\($0.name ?? "")    \(input[$0.range])" })

			"""
		}

		@inlinable
		public subscript(one name: String) -> Range<Input.Index>? {
			return captures.first(where: { $0.name == name })?.range
		}

		@inlinable
		public subscript(multiple name: String) -> [Range<Input.Index>] {
			return captures.filter { $0.name == name }.map(\.range)
		}

		public var names: Set<String> { Set(captures.compactMap(\.name)) }
	}

	@usableFromInline
	internal func match(in input: Input, at startindex: Input.Index) -> Match? {
		return matcher.match(in: input, at: startindex)
	}

	@usableFromInline
	internal func match(in input: Input, from startIndex: Input.Index) -> Match? {
		return matcher.match(in: input, from: startIndex)
	}

	@inlinable
	public func matches(in input: Input, from startindex: Input.Index? = nil)
		-> UnfoldSequence<Match, Input.Index> {
		var previousRange: Range<Input.Index>?
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
