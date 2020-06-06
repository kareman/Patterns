//
//  OneOf.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

public struct OneOf: Pattern, RegexConvertible {
	let group: Group<Input.Element>
	public let description: String
	private let _regex: String?
	public var regex: String {
		_regex ?? fatalError("Regex not provided for '\(description)'")
	}

	public init(description: String, regex: String? = nil, group: Group<Input.Element>) {
		self.group = group
		self.description = description
		self._regex = regex
	}

	public init(description: String, regex: String? = nil, contains: @escaping (Input.Element) -> Bool) {
		self.init(description: description, regex: regex, group: Group(contains: contains))
	}

	public init<S: Sequence>(_ characters: S) where S.Element == Input.Element {
		group = Group(contentsOf: characters)
		description = "\"\(group)\""
		_regex = "[\(NSRegularExpression.escapedPattern(for: characters.map(String.init(describing:)).joined()))]"
	}

	public func createInstructions(_ instructions: inout Instructions) {
		instructions.append(.checkCharacter(group.contains))
	}
}

// MARK: Join `&&OneOf • OneOf` into one.

public func • (lhs: AndPattern<OneOf>, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) \(rhs)", group: lhs.wrapped.group.intersection(rhs.group))
}

public func • <P: Pattern>(lhs: AndPattern<OneOf>, rhs: ConcatenationPattern<OneOf, P>) -> ConcatenationPattern<OneOf, P> {
	(lhs • rhs.left) • rhs.right
}

// MARK: Join `!OneOf • Oneof` into one.

public func • (lhs: NotPattern<OneOf>, rhs: OneOf) -> OneOf {
	OneOf(description: "\(lhs) \(rhs)", group: rhs.group.subtracting(lhs.wrapped.group))
}

public func • <P: Pattern>(lhs: NotPattern<OneOf>, rhs: ConcatenationPattern<OneOf, P>) -> ConcatenationPattern<OneOf, P> {
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
                         contains: \Character.isWholeNumber)
public let letter = OneOf(description: "letter", regex: #"\p{Alphabetic}"#,
                          contains: \Character.isLetter)
public let lowercase = OneOf(description: "lowercase", regex: #"\p{Ll}"#,
                             contains: \Character.isLowercase)
public let newline = OneOf(description: "newline", regex: #"\p{Zl}"#,
                           contains: \Character.isNewline)
public let punctuation = OneOf(description: "punctuation", regex: #"\p{P}"#,
                               contains: \Character.isPunctuation)
public let symbol = OneOf(description: "symbol", regex: #"\p{S}"#,
                          contains: \Character.isSymbol)
public let uppercase = OneOf(description: "uppercase", regex: #"\p{Lu}"#,
                             contains: \Character.isUppercase)
public let whitespace = OneOf(description: "whitespace", regex: #"\p{White_Space}"#,
                              contains: \Character.isWhitespace)
public let hexDigit = OneOf(description: "hexDigit", regex: #"\p{Hex_Digit}"#,
                            contains: \Character.isHexDigit)
public let ascii = OneOf(description: "ascii", regex: #"[[:ascii:]]"#,
                         contains: \Character.isASCII) // regex might also be [ -~] or [\x00-\x7F]
public let mathSymbol = OneOf(description: "mathSymbol", regex: #"\p{Sm}"#,
                              contains: \Character.isMathSymbol)
public let currencySymbol = OneOf(description: "currencySymbol", regex: #"\p{Sc}"#,
                                  contains: \Character.isCurrencySymbol)

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
