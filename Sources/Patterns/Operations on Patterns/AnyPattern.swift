//
//  StringInterpolation.swift
//  Patterns
//
//  Created by Kåre Morstøl on 11/08/2019.
//

/// A type erased wrapper around a pattern.
/// Can be used to store patterns in arrays and non-generic variables.
public struct AnyPattern<Input: BidirectionalCollection>: Pattern where Input.Element: Hashable {
	@usableFromInline
	let _instructions: (inout ContiguousArray<Instruction<Input>>) throws -> Void

	@inlinable
	public func createInstructions(_ instructions: inout ContiguousArray<Instruction<Input>>) throws {
		try _instructions(&instructions)
	}

	private let _description: () -> String
	public var description: String { _description() }

	/// The wrapped pattern. If you know the exact type you can unwrap it again.
	public let wrapped: Any

	public init<P: Pattern>(_ p: P) where Input == P.Input {
		_instructions = p.createInstructions
		_description = { p.description }
		wrapped = p
	}

	@inlinable
	public init(_ p: AnyPattern) {
		self = p
	}

	public init(_ p: Literal<Input>) {
		_instructions = p.createInstructions
		_description = { p.description }
		wrapped = p
	}

	public static func == (lhs: AnyPattern, rhs: AnyPattern) -> Bool {
		lhs.description == rhs.description
	}
}

extension AnyPattern: ExpressibleByUnicodeScalarLiteral where Input == String {
	@inlinable
	public init(unicodeScalarLiteral value: String) {
		self.init(stringLiteral: String(describing: value))
	}
}

extension AnyPattern: ExpressibleByExtendedGraphemeClusterLiteral where Input == String {
	public typealias ExtendedGraphemeClusterLiteralType = String
}

extension AnyPattern: ExpressibleByStringLiteral where Input == String {
	public typealias StringLiteralType = String
}

/// Allows AnyPattern to be defined by a string with patterns in interpolations.
///
/// `let p: AnyPattern = "hi\(whitespace)there"`
/// is the same as `"hi" • whitespace • "there"`.
extension AnyPattern: ExpressibleByStringInterpolation where Input == String {
	public struct StringInterpolation: StringInterpolationProtocol {
		@usableFromInline
		var pattern = AnyPattern("")

		@inlinable
		public init(literalCapacity: Int, interpolationCount: Int) {}

		@inlinable
		public mutating func appendLiteral(_ literal: String) {
			if !literal.isEmpty {
				pattern = AnyPattern(pattern • Literal(literal))
			}
		}

		@inlinable
		public mutating func appendInterpolation<P: Pattern>(_ newpattern: P) where P.Input == Input {
			pattern = AnyPattern(pattern • newpattern)
		}
	}

	@inlinable
	public init(stringLiteral value: String) {
		self.init(Literal(value))
	}

	@inlinable
	public init(stringInterpolation: StringInterpolation) {
		self.init(stringInterpolation.pattern)
	}
}
