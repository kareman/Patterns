//
//  StringInterpolation.swift
//  Patterns
//
//  Created by Kåre Morstøl on 11/08/2019.
//

/// A type erased wrapper around a pattern.
/// Can be used to store patterns in arrays and non-generic variables.
public struct AnyPattern: Pattern {
	@usableFromInline
	let _instructions: (inout Instructions) throws -> Void

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		try _instructions(&instructions)
	}

	private let _description: () -> String
	public var description: String { _description() }

	/// The wrapped pattern. If you know the exact type you can unwrap it again.
	public let wrapped: Any

	public init(_ p: Pattern) {
		_instructions = p.createInstructions
		_description = { p.description }
		wrapped = p
	}

	@inlinable
	public init(_ p: AnyPattern) {
		self = p
	}

	public init(_ p: Literal) {
		_instructions = p.createInstructions
		_description = { p.description }
		wrapped = p
	}
}

/// Allows AnyPattern to be defined by a string with patterns in interpolations.
///
/// `let p: AnyPattern = "hi\(whitespace)there"`
/// is the same as `"hi" • whitespace • "there"`.
extension AnyPattern: ExpressibleByStringInterpolation {
	public struct StringInterpolation: StringInterpolationProtocol {
		@usableFromInline
		var patterns = [Pattern]()

		@inlinable
		public init(literalCapacity: Int, interpolationCount: Int) {
			patterns.reserveCapacity(literalCapacity + interpolationCount)
		}

		@inlinable
		public mutating func appendLiteral(_ literal: String) {
			if !literal.isEmpty {
				patterns.append(Literal(literal))
			}
		}

		@inlinable
		public mutating func appendInterpolation(_ newpatterns: Pattern...) {
			patterns.append(contentsOf: newpatterns)
		}
	}

	@inlinable
	public init(stringLiteral value: String) {
		self.init(Literal(value))
	}

	@inlinable
	public init(stringInterpolation: StringInterpolation) {
		var patterns = stringInterpolation.patterns[...]
		guard let first = patterns.popFirst() else {
			self.init(Literal(""))
			return
		}
		guard let second = patterns.popFirst() else {
			self.init(first)
			return
		}
		var result = AnyPattern(first) • AnyPattern(second)
		while let next = patterns.popFirst() {
			result = AnyPattern(result) • AnyPattern(next)
		}
		self.init(result)
	}
}
