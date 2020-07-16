//
//  OneOf.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

/// Matches and consumes a single element.
public struct OneOf<Input: BidirectionalCollection>: Pattern /*, RegexConvertible*/ where Input.Element: Hashable {
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

	/// Matches any element for which `contains` returns `true`.
	/// - Parameters:
	///   - description: A descriptive identifier for textual representation of the pattern.
	///   - regex: An optional regex matching the same elements.
	///   - contains: A closure returning true for any element that matches.
	@inlinable
	public init(description: String, regex: String? = nil, contains: @escaping (Input.Element) -> Bool) where Input == String {
		self.init(description: description, regex: regex, group: Group(contains: contains))
	}

	/// Matches any elements in `elements`.
	/// - Parameter elements: A sequence of elements to match.
	@inlinable
	public init(_ elements: Input) {
		group = Group(contentsOf: elements)
		description = "[\(String(describing: elements))]"
		_regex = "[\(NSRegularExpression.escapedPattern(for: elements.map(String.init(describing:)).joined()))]"
	}

	/// Matches any elements _not_ in `elements`.
	/// - Parameter elements: A sequence of elements _not_ to match.
	@inlinable
	public init(not elements: Input) {
		group = Group(contentsOf: elements).inverted()
		description = "[^\(String(describing: elements))]"
		_regex = "[^\(NSRegularExpression.escapedPattern(for: elements.map(String.init(describing:)).joined()))]"
	}

	@inlinable
	public func createInstructions(_ instructions: inout Self.Instructions) {
		instructions.append(.checkElement(group.contains))
	}

	public static func == (lhs: OneOf, rhs: OneOf) -> Bool {
		lhs.description == rhs.description
	}
}

// MARK: OneOfConvertible

// Allows for e.g. `OneOf("a" ..< "e", "g", uppercase)` and `OneOf(not: "a" ..< "e", "gåopr", uppercase)`

/// A type that `OneOf` can use.
public protocol OneOfConvertible {
	associatedtype Element: Hashable
	@inlinable
	func contains(_: Element) -> Bool
}

extension OneOf: OneOfConvertible {
	@inlinable
	public func contains(_ char: Input.Element) -> Bool { group.contains(char) }
}

extension Character: OneOfConvertible {
	@inlinable
	public func contains(_ char: Character) -> Bool { char == self }
}

/* Should have been
 extension Collection: OneOfConvertible where Element: Hashable { }
 but "Extension of protocol 'Collection' cannot have an inheritance clause".
 */
extension String: OneOfConvertible {}
extension Substring: OneOfConvertible {}
extension String.UTF8View: OneOfConvertible {}
extension Substring.UTF8View: OneOfConvertible {}
extension String.UTF16View: OneOfConvertible {}
extension Substring.UTF16View: OneOfConvertible {}
extension String.UnicodeScalarView: OneOfConvertible {}
extension Substring.UnicodeScalarView: OneOfConvertible {}

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

extension OneOf {
	/* It will be a glorious day when all this can be replaced by two methods using variadic generics. */

	@usableFromInline
	internal init(closures: [(Input.Element) -> Bool], description: String, isNegated: Bool = false) {
		group = Group(contains: isNegated
			? { element in !closures.contains(where: { $0(element) }) }
			: { element in closures.contains(where: { $0(element) }) })
		self.description = description
		_regex = nil
	}

	/// Matches any of the provided elements.
	@inlinable
	public init<O1: OneOfConvertible>(_ o1: O1)
		where Input.Element == O1.Element {
		let closures = [o1.contains(_:)]
		self.init(closures: closures, description: "[\(o1)]")
	}

	/// Matches any of the provided elements.
	@inlinable
	public init<O1: OneOfConvertible, O2: OneOfConvertible>(_ o1: O1, _ o2: O2)
		where Input.Element == O1.Element, O1.Element == O2.Element {
		let closures = [o1.contains(_:), o2.contains(_:)]
		self.init(closures: closures, description: "[\(o1), \(o2)]")
	}

	/// Matches any of the provided elements.
	@inlinable
	public init<O1: OneOfConvertible, O2: OneOfConvertible, O3: OneOfConvertible>(_ o1: O1, _ o2: O2, _ o3: O3)
		where Input.Element == O1.Element, O1.Element == O2.Element, O2.Element == O3.Element {
		let closures = [o1.contains(_:), o2.contains(_:), o3.contains(_:)]
		self.init(closures: closures, description: "[\(o1), \(o2), \(o3)]")
	}

	/// Matches any of the provided elements.
	@inlinable
	public init<O1: OneOfConvertible, O2: OneOfConvertible, O3: OneOfConvertible, O4: OneOfConvertible>
	(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4)
		where Input.Element == O1.Element, O1.Element == O2.Element, O2.Element == O3.Element, O3.Element == O4.Element {
		let closures = [o1.contains(_:), o2.contains(_:), o3.contains(_:), o4.contains(_:)]
		self.init(closures: closures, description: "[\(o1), \(o2), \(o3), \(o4)]")
	}

	// Not

	/// Matches any _but_ the provided elements.
	@inlinable
	public init<O1: OneOfConvertible>(not o1: O1)
		where Input.Element == O1.Element {
		let closures = [o1.contains(_:)]
		self.init(closures: closures, description: "[^\(o1)]", isNegated: true)
	}

	/// Matches any _but_ the provided elements.
	@inlinable
	public init<O1: OneOfConvertible, O2: OneOfConvertible>(not o1: O1, _ o2: O2)
		where Input.Element == O1.Element, O1.Element == O2.Element {
		let closures = [o1.contains(_:), o2.contains(_:)]
		self.init(closures: closures, description: "[^\(o1), \(o2)]", isNegated: true)
	}

	/// Matches any _but_ the provided elements.
	@inlinable
	public init<O1: OneOfConvertible, O2: OneOfConvertible, O3: OneOfConvertible>(not o1: O1, _ o2: O2, _ o3: O3)
		where Input.Element == O1.Element, O1.Element == O2.Element, O2.Element == O3.Element {
		let closures = [o1.contains(_:), o2.contains(_:), o3.contains(_:)]
		self.init(closures: closures, description: "[^\(o1), \(o2), \(o3)]", isNegated: true)
	}

	/// Matches any of the provided elements.
	@inlinable
	public init<O1: OneOfConvertible, O2: OneOfConvertible, O3: OneOfConvertible, O4: OneOfConvertible>
	(not o1: O1, _ o2: O2, _ o3: O3, _ o4: O4)
		where Input.Element == O1.Element, O1.Element == O2.Element, O2.Element == O3.Element, O3.Element == O4.Element {
		let closures = [o1.contains(_:), o2.contains(_:), o3.contains(_:), o4.contains(_:)]
		self.init(closures: closures, description: "[^\(o1), \(o2), \(o3), \(o4)]", isNegated: true)
	}
}

/* TODO: uncomment
 // MARK: Join `&&OneOf • OneOf` into one.

 @inlinable
 public func • <Input>(lhs: AndPattern<OneOf<Input>>, rhs: OneOf<Input>) -> OneOf<Input> {
 OneOf(description: "\(lhs) \(rhs)", group: lhs.wrapped.group.intersection(rhs.group))
 }

 @inlinable
 public func • <P: Pattern>(lhs: Concat<P, AndPattern<OneOf<P.Input>>>, rhs: OneOf<P.Input>) -> Concat<P, OneOf<P.Input>> {
 lhs.first • (lhs.second • rhs)
 }

 // MARK: Join `!OneOf • Oneof` into one.

 @inlinable
 public func • <Input>(lhs: NotPattern<OneOf<Input>>, rhs: OneOf<Input>) -> OneOf<Input> {
 OneOf(description: "\(lhs) \(rhs)", group: rhs.group.subtracting(lhs.wrapped.group))
 }

 @inlinable
 public func • <P: Pattern>(lhs: Concat<P, NotPattern<OneOf<P.Input>>>, rhs: OneOf<P.Input>) -> Concat<P, OneOf<P.Input>> {
 lhs.first • (lhs.second • rhs)
 }

 // MARK: Join `OneOf / OneOf` into one.

 @inlinable
 public func / <Input>(lhs: OneOf<Input>, rhs: OneOf<Input>) -> OneOf<Input> {
 OneOf(description: "\(lhs) / \(rhs)", group: lhs.group.union(rhs.group))
 }

 @inlinable
 public func / <P: Pattern>(lhs: OrPattern<P, OneOf<P.Input>>, rhs: OneOf<P.Input>) -> OrPattern<P, OneOf<P.Input>> {
 lhs.first / (lhs.second / rhs)
 }
 */

// MARK: Common patterns.

/// Succeeds anywhere except for at the end of input, and consumes 1 element.
public let any = OneOf(description: "any", regex: #"[.\p{Zl}]"#,
                       contains: { _ in true })
/// Matches one character representing a letter, i.e. where `Character.isLetter` is `true`.
public let letter = OneOf(description: "letter", regex: #"\p{Alphabetic}"#,
                          contains: { $0.isLetter })
/// Matches one character representing a lowercase character, i.e. where `Character.isLowercase` is `true`.
public let lowercase = OneOf(description: "lowercase", regex: #"\p{Ll}"#,
                             contains: { $0.isLowercase })
/// Matches one character representing an uppercase character, i.e. where `Character.isUppercase` is `true`.
public let uppercase = OneOf(description: "uppercase", regex: #"\p{Lu}"#,
                             contains: { $0.isUppercase })
/// Matches one character representing a whole number, i.e. where `Character.isWholeNumber` is `true`.
public let digit = OneOf(description: "digit", regex: #"\p{Nd}"#,
                         contains: { $0.isWholeNumber })
/// Matches one letter or one digit.
public let alphanumeric = OneOf(description: "alphanumeric", regex: #"(?:\p{Alphabetic}|\p{Nd})"#,
                                contains: { $0.isWholeNumber || $0.isLetter })
/// Matches one character representing a newline, i.e. where `Character.isNewline` is `true`.
public let newline = OneOf(description: "newline", regex: #"\p{Zl}"#,
                           contains: { $0.isNewline })
/// Matches one character representing whitespace (including newlines), i.e. where `Character.isWhitespace` is `true`.
public let whitespace = OneOf(description: "whitespace", regex: #"\p{White_Space}"#,
                              contains: { $0.isWhitespace })
/// Matches one character representing punctuation, i.e. where `Character.isPunctuation` is `true`.
public let punctuation = OneOf(description: "punctuation", regex: #"\p{P}"#,
                               contains: { $0.isPunctuation })
/// Matches one character representing a symbol, i.e. where `Character.isSymbol` is `true`.
public let symbol = OneOf(description: "symbol", regex: #"\p{S}"#,
                          contains: { $0.isSymbol })
/// Matches one character representing a hexadecimal digit, i.e. where `Character.isHexDigit` is `true`.
public let hexDigit = OneOf(description: "hexDigit", regex: #"\p{Hex_Digit}"#,
                            contains: { $0.isHexDigit })
/// Matches one ASCII character, i.e. where `Character.isASCII` is `true`.
public let ascii = OneOf(description: "ascii", regex: #"[[:ascii:]]"#,
                         contains: { $0.isASCII }) // regex might also be [ -~] or [\x00-\x7F]
/// Matches one character representing a mathematical symbol, i.e. where `Character.isMathSymbol` is `true`.
public let mathSymbol = OneOf(description: "mathSymbol", regex: #"\p{Sm}"#,
                              contains: { $0.isMathSymbol })
/// Matches one character representing a currency symbol, i.e. where `Character.isCurrencySymbol` is `true`.
public let currencySymbol = OneOf(description: "currencySymbol", regex: #"\p{Sc}"#,
                                  contains: { $0.isCurrencySymbol })

extension OneOf where Input == String {
	/// Predefined OneOf patterns.
	public static var patterns: [OneOf] {
		[alphanumeric, letter, lowercase, uppercase, punctuation, whitespace, newline, hexDigit, digit,
		 ascii, symbol, mathSymbol, currencySymbol]
	}

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
