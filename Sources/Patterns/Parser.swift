//
//  Parser.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

/// Takes a pattern, optimises it and tries to match it over an input.
public struct Parser<Input: BidirectionalCollection> where Input.Element: Hashable {
	/// Indicates a problem with a malformed pattern.
	public enum PatternError: Error, CustomStringConvertible {
		/// The error message from the parser.
		case message(String)

		public var description: String {
			switch self {
			case let .message(string):
				return string
			}
		}
	}

	@usableFromInline
	let matcher: VMEngine<Input>

	/// A parser which matches `pattern` _at_ a given position.
	@inlinable
	public init<P: Pattern>(_ pattern: P) throws where P.Input == Input {
		self.matcher = try VMEngine(pattern)
	}

	/// A parser which searches for `pattern` _from_ a given position.
	///
	/// Is the same as `Parser(Skip() • pattern)`.
	@inlinable
	public init<P: Pattern>(search pattern: P) throws where P.Input == Input {
		try self.init(Skip() • pattern)
	}

	/// Contains information about a patterns successfully completed match.
	public struct Match: Equatable {
		/// The position in the input when the pattern completed.
		///
		/// - note: If the last part of the pattern is a `!` or `&&`,
		/// `endIndex` is the position when that last part _started_.
		public let endIndex: Input.Index

		/// The names and ranges of all captures.
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

		/// The range from the beginning of the first capture to the end of the last one.
		/// If there are no captures, the empty range at the `endIndex` of this Match.
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

		/// Returns the first capture named `name`.
		@inlinable
		public subscript(one name: String) -> Range<Input.Index>? {
			captures.first(where: { $0.name == name })?.range
		}

		/// Returns all captures named `name`.
		@inlinable
		public subscript(multiple name: String) -> [Range<Input.Index>] {
			captures.filter { $0.name == name }.map { $0.range }
		}

		/// The names of all the captures.
		@inlinable
		public var captureNames: Set<String> { Set(captures.compactMap { $0.name }) }
	}

	/// Tries to match the pattern in `input` at `index`.
	/// - Parameters:
	///   - index: The position to match at, if not provided the beginning of input will be used.
	@inlinable
	public func match(in input: Input, at index: Input.Index? = nil) -> Match? {
		matcher.match(in: input, at: index ?? input.startIndex)
	}

	/// A lazily generated sequence of consecutive matches of the pattern in `input`.
	///
	/// Each match attempt starts at the `.range.upperBound` of the previous match,
	/// so the matches can be overlapping.
	///
	/// You can dictate where the next match should start by where you place the last capture.
	///
	/// - Parameters:
	///   - startindex: The position to match from, if not provided the beginning of input will be used.
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
			let matchEnd = match.range.upperBound
			if matchEnd == index {
				guard matchEnd != input.endIndex else {
					stop = true
					return match
				}
				input.formIndex(after: &index)
			} else {
				index = matchEnd
			}
			return match
		})
	}
}
