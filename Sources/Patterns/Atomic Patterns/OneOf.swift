//
//  OneOf.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

/// Matches and consumes a single element.
public struct OneOf: Pattern, RegexConvertible {
	@usableFromInline
	let group: Group<Input.Element>
	public let description: String

	@usableFromInline
	let _regex: String?
	public var regex: String {
		_regex ?? fatalError("Regex not provided for '\(description)'")
	}

	@usableFromInline
	init(description: String, regex: String? = nil, group: Group<Input.Element>) {
		self.group = group
		self.description = description
		self._regex = regex
	}

	/// Matches any element for which `contains` returns `true`.
	/// - Parameters:
	///   - description: A descriptive identifier for textual representation of the pattern.
	///   - regex: An optional regex matching the same elements.
	///   - contains: A closure returning true for any element that matches.
	@inlinable
	public init(description: String, regex: String? = nil, contains: @escaping (Input.Element) -> Bool) {
		self.init(description: description, regex: regex, group: Group(contains: contains))
	}

	/// Matches any elements in `elements`.
	/// - Parameter elements: A sequence of elements to match.
	@inlinable
	public init<S: Sequence>(_ elements: S) where S.Element == Input.Element {
		group = Group(contentsOf: elements)
		description = #"[\#(String(elements))]"#
		_regex = "[\(NSRegularExpression.escapedPattern(for: elements.map(String.init(describing:)).joined()))]"
	}

	/// Matches any elements _not_ in `elements`.
	/// - Parameter elements: A sequence of elements _not_ to match.
	@inlinable
	public init<S: Sequence>(not elements: S) where S.Element == Input.Element {
		group = Group(contentsOf: elements).inverted()
		description = #"[^\#(String(elements))]"#
		_regex = "[^\(NSRegularExpression.escapedPattern(for: elements.map(String.init(describing:)).joined()))]"
	}

	/// Matches any of the provided elements.
	@inlinable
	public init(_ oneofs: OneOfConvertible...) {
		let closures = oneofs.map { $0.contains(_:) }
		group = Group(contains: { char in closures.contains(where: { $0(char) }) })
		description = "[\(oneofs.map(String.init(describing:)).joined(separator: ","))]"
		_regex = nil
	}

	/// Matches anything that is _not_ among the provided elements.
	@inlinable
	public init(not oneofs: OneOfConvertible...) {
		let closures = oneofs.map { $0.contains(_:) }
		group = Group(contains: { char in !closures.contains(where: { $0(char) }) })
		description = #"[^\#(oneofs.map(String.init(describing:)).joined(separator: ","))]"#
		_regex = nil
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) {
		instructions.append(.checkElement(group.contains))
	}
}

// MARK: OneOfConvertible

/// A type that `OneOf` can use.
public protocol OneOfConvertible {
	@inlinable
	func contains(_: Pattern.Input.Element) -> Bool
}

extension Character: OneOfConvertible {
	@inlinable
	public func contains(_ char: Pattern.Input.Element) -> Bool { char == self }
}

extension String: OneOfConvertible {}
extension Substring: OneOfConvertible {}

@inlinable
public func ... (lhs: Character, rhs: Character) -> ClosedRange<Character> {
	precondition(lhs <= rhs, "The left side of the '...' operator must be less than or equal to the right side.")
	return ClosedRange(uncheckedBounds: (lower: lhs, upper: rhs))
}

extension ClosedRange: OneOfConvertible where Bound == Character {}

@inlinable
public func ..< (lhs: Character, rhs: Character) -> Range<Character> {
	precondition(lhs <= rhs, "The left side of the '..<' operator must be less than or equal to the right side.")
	return Range(uncheckedBounds: (lower: lhs, upper: rhs))
}

extension Range: OneOfConvertible where Bound == Character {}

extension OneOf: OneOfConvertible {
	@inlinable
	public func contains(_ char: Pattern.Input.Element) -> Bool { group.contains(char) }
}

// MARK: Join `&&OneOf • OneOf` into one.

@inlinable
public func • (lhs: AndPattern<OneOf>, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) \(rhs)", group: lhs.wrapped.group.intersection(rhs.group))
}

@inlinable
public func • <P: Pattern>(lhs: Concat<P, AndPattern<OneOf>>, rhs: OneOf) -> Concat<P, OneOf> {
	lhs.first • (lhs.second • rhs)
}

// MARK: Join `!OneOf • Oneof` into one.

@inlinable
public func • (lhs: NotPattern<OneOf>, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) \(rhs)", group: rhs.group.subtracting(lhs.wrapped.group))
}

@inlinable
public func • <P: Pattern>(lhs: Concat<P, NotPattern<OneOf>>, rhs: OneOf) -> Concat<P, OneOf> {
	lhs.first • (lhs.second • rhs)
}

// MARK: Join `OneOf / OneOf` into one.

@inlinable
public func / (lhs: OneOf, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) / \(rhs)", group: lhs.group.union(rhs.group))
}

@inlinable
public func / <P: Pattern>(lhs: OrPattern<P, OneOf>, rhs: OneOf) -> OrPattern<P, OneOf> {
	lhs.first / (lhs.second / rhs)
}

// MARK: Common patterns.

/// Succeeds anywhere except for the end of input, and consumes 1 element.
public let any = OneOf(description: "any", regex: #"[.\p{Zl}]"#,
                       contains: { _ in true })
public let alphanumeric = OneOf(description: "alphanumeric", regex: #"(?:\p{Alphabetic}|\p{Nd})"#,
                                contains: { $0.isWholeNumber || $0.isLetter })
public let digit = OneOf(description: "digit", regex: #"\p{Nd}"#,
                         contains: { $0.isWholeNumber })
public let letter = OneOf(description: "letter", regex: #"\p{Alphabetic}"#,
                          contains: { $0.isLetter })
public let lowercase = OneOf(description: "lowercase", regex: #"\p{Ll}"#,
                             contains: { $0.isLowercase })
public let newline = OneOf(description: "newline", regex: #"\p{Zl}"#,
                           contains: { $0.isNewline })
public let punctuation = OneOf(description: "punctuation", regex: #"\p{P}"#,
                               contains: { $0.isPunctuation })
public let symbol = OneOf(description: "symbol", regex: #"\p{S}"#,
                          contains: { $0.isSymbol })
public let uppercase = OneOf(description: "uppercase", regex: #"\p{Lu}"#,
                             contains: { $0.isUppercase })
public let whitespace = OneOf(description: "whitespace", regex: #"\p{White_Space}"#,
                              contains: { $0.isWhitespace })
public let hexDigit = OneOf(description: "hexDigit", regex: #"\p{Hex_Digit}"#,
                            contains: { $0.isHexDigit })
public let ascii = OneOf(description: "ascii", regex: #"[[:ascii:]]"#,
                         contains: { $0.isASCII }) // regex might also be [ -~] or [\x00-\x7F]
public let mathSymbol = OneOf(description: "mathSymbol", regex: #"\p{Sm}"#,
                              contains: { $0.isMathSymbol })
public let currencySymbol = OneOf(description: "currencySymbol", regex: #"\p{Sc}"#,
                                  contains: { $0.isCurrencySymbol })

extension OneOf {
	/// Predefined OneOf patterns.
	public static let patterns: [OneOf] = [
		alphanumeric, letter, lowercase, uppercase, punctuation, whitespace, newline, hexDigit, digit,
		ascii, symbol, mathSymbol, currencySymbol,
	]

	/// All the predefined OneOf patterns that match `element`.
	public static func patterns(for element: Input.Element) -> [OneOf] {
		OneOf.patterns.filter { $0.group.contains(element) }
	}

	/// The predefined OneOf patterns that match _all_ the elements in `sequence`.
	public static func patterns<S: Sequence>(for sequence: S) -> [OneOf] where S.Element == Input.Element {
		let sequence = ContiguousArray(sequence)
		return OneOf.patterns.filter { $0.group.contains(contentsOf: sequence) }
	}
}
