//
//  Parser.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

public struct Parser<Input: BidirectionalCollection> where Input.Element: Hashable {
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

	@usableFromInline
	let matcher: VMBacktrackEngine<Input>

	@inlinable
	public init<P: Pattern>(_ pattern: P) throws where P.Input == Input {
		self.matcher = try VMBacktrackEngine(pattern)
	}

	@inlinable
	public init<P: Pattern>(search pattern: P) throws where P.Input == Input {
		try self.init(Skip() • pattern)
	}

	@inlinable
	public func ranges(in input: Input, from startindex: Input.Index? = nil)
		-> AnySequence<Range<Input.Index>> {
		AnySequence(matches(in: input, from: startindex).lazy.map { $0.range })
	}

	public struct Match: Equatable {
		public let endIndex: Input.Index
		public let captures: [(name: String?, range: Range<Input.Index>)]

		@inlinable
		init(endIndex: Input.Index, captures: [(name: String?, range: Range<Input.Index>)]) {
			self.endIndex = endIndex
			self.captures = captures
		}

		@inlinable
		public static func == (lhs: Parser<Input>.Match, rhs: Parser<Input>.Match) -> Bool {
			lhs.endIndex == rhs.endIndex
				&& lhs.captures.elementsEqual(rhs.captures, by: { left, right in
					left.range == right.range && left.name == right.name
				})
		}

		@inlinable
		public var range: Range<Input.Index> {
			// TODO: Is `captures.last!.range.upperBound` always the highest captured index?
			// What if there is one large range and a smaller inside that?
			captures.isEmpty
				? endIndex ..< endIndex
				: captures.first!.range.lowerBound ..< captures.last!.range.upperBound
		}

		public func description(using input: Input) -> String {
			"""
			endIndex: "\(endIndex == input.endIndex ? "EOF" : String(describing: input[endIndex]))"
			\(captures.map { "\($0.name.map { $0 + ":" } ?? "") \(input[$0.range])" }.joined(separator: "\n"))

			"""
		}

		@inlinable
		public subscript(one name: String) -> Range<Input.Index>? {
			captures.first(where: { $0.name == name })?.range
		}

		@inlinable
		public subscript(multiple name: String) -> [Range<Input.Index>] {
			captures.filter { $0.name == name }.map { $0.range }
		}

		@inlinable
		public var names: Set<String> { Set(captures.compactMap { $0.name }) }
	}

	@inlinable
	public func match(in input: Input, at startIndex: Input.Index? = nil) -> Match? {
		matcher.match(in: input, from: startIndex ?? input.startIndex)
	}

	@inlinable
	public func matches(in input: Input, from startindex: Input.Index? = nil)
		-> UnfoldSequence<Match, Input.Index> {
		var stop = false
		var lastMatch: Match?
		return sequence(state: startindex ?? input.startIndex, next: { (index: inout Input.Index) in
			guard var match = self.match(in: input, at: index), !stop else { return nil }
			if match == lastMatch {
				guard index != input.endIndex else { return nil }
				input.formIndex(after: &index)
				guard let newMatch = self.match(in: input, at: index) else { return nil }
				match = newMatch
			}
			lastMatch = match
			let range = match.range
			if range.upperBound == index {
				guard range.upperBound != input.endIndex else {
					stop = true
					return match
				}
				input.formIndex(after: &index)
			} else {
				index = range.upperBound
			}
			return match
		})
	}
}
