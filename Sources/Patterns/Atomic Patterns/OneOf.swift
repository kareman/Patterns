//
//  OneOf.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

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

	@inlinable
	public init(description: String, regex: String? = nil, contains: @escaping (Input.Element) -> Bool) {
		self.init(description: description, regex: regex, group: Group(contains: contains))
	}

	@inlinable
	public init<S: Sequence>(_ characters: S) where S.Element == Input.Element {
		group = Group(contentsOf: characters)
		description = #"["\#(String(characters))"]"#
		_regex = "[\(NSRegularExpression.escapedPattern(for: characters.map(String.init(describing:)).joined()))]"
	}

	@inlinable
	public init<S: Sequence>(not characters: S) where S.Element == Input.Element {
		group = Group(contentsOf: characters).inverted()
		description = #"[^"\#(String(characters))"]"#
		_regex = "[^\(NSRegularExpression.escapedPattern(for: characters.map(String.init(describing:)).joined()))]"
	}

	@inlinable
	public init(_ oneofs: OneOfConvertible...) {
		let closures = oneofs.map { $0.contains(_:) }
		group = Group(contains: { char in closures.contains(where: { $0(char) }) })
		description = #"[\#(oneofs.map(String.init(describing:)).joined(separator: ","))]"#
		_regex = nil
	}

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

public protocol OneOfConvertible {
	func contains(_: Character) -> Bool
}

extension Character: OneOfConvertible {
	public func contains(_ char: Character) -> Bool { char == self }
}

extension String: OneOfConvertible {}
extension Substring: OneOfConvertible {}

public func ... (lhs: Character, rhs: Character) -> ClosedRange<Character> {
	precondition(lhs <= rhs, "The left side of the '...' operator must be less than or equal to the right side")
	return ClosedRange(uncheckedBounds: (lower: lhs, upper: rhs))
}

extension ClosedRange: OneOfConvertible where Bound == Character {}

public func ..< (lhs: Character, rhs: Character) -> Range<Character> {
	precondition(lhs <= rhs, "The left side of the '..<' operator must be less than or equal to the right side")
	return Range(uncheckedBounds: (lower: lhs, upper: rhs))
}

extension Range: OneOfConvertible where Bound == Character {}

extension OneOf: OneOfConvertible {
	public func contains(_ char: Character) -> Bool { group.contains(char) }
}

// MARK: Join `&&OneOf • OneOf` into one.

public func • (lhs: AndPattern<OneOf>, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) \(rhs)", group: lhs.wrapped.group.intersection(rhs.group))
}

public func • <P: Pattern>(lhs: AndPattern<OneOf>, rhs: Concat<OneOf, P>) -> Concat<OneOf, P> {
	(lhs • rhs.left) • rhs.right
}

// MARK: Join `!OneOf • Oneof` into one.

public func • (lhs: NotPattern<OneOf>, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) \(rhs)", group: rhs.group.subtracting(lhs.wrapped.group))
}

public func • <P: Pattern>(lhs: NotPattern<OneOf>, rhs: Concat<OneOf, P>) -> Concat<OneOf, P> {
	(lhs • rhs.left) • rhs.right
}

// MARK: Join `OneOf / OneOf` into one.

public func / (lhs: OneOf, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) / \(rhs)", group: lhs.group.union(rhs.group))
}

public func / <P: Pattern>(lhs: OrPattern<P, OneOf>, rhs: OneOf) -> OrPattern<P, OneOf> {
	lhs.first / (lhs.second / rhs)
}

// MARK: Common patterns.

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
	public static let basePatterns: [OneOf] = [
		any, alphanumeric, letter, lowercase, uppercase, punctuation, whitespace, newline, hexDigit, digit,
		ascii, symbol, mathSymbol, currencySymbol,
	]

	public static func patterns(for c: Input.Element) -> [Pattern] {
		OneOf.basePatterns.filter { $0.group.contains(c) }
	}

	public static func patterns<S: Sequence>(for s: S) -> [Pattern] where S.Element == Input.Element {
		OneOf.basePatterns.filter { $0.group.contains(contentsOf: s) }
	}
}
