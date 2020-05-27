//
//  StringInterpolation.swift
//  Patterns
//
//  Created by Kåre Morstøl on 11/08/2019.
//

public struct AnyPattern: Pattern {
	private let _instructions: () -> [Instruction<Input>]
	public func createInstructions() -> [Instruction<Input>] {
		_instructions()
	}

	private let _description: () -> String
	public var description: String { _description() }

	public let wrapped: Any

	init(_ p: Pattern) {
		_instructions = { p.createInstructions() }
		_description = { p.description }
		wrapped = p
	}

	init(_ p: AnyPattern) {
		self = p
	}

	init(_ p: Literal) {
		_instructions = { p.createInstructions() }
		_description = { p.description }
		wrapped = p
	}
}

extension AnyPattern: ExpressibleByStringInterpolation {
	public struct StringInterpolation: StringInterpolationProtocol {
		var patterns = [Pattern]()

		public init(literalCapacity: Int, interpolationCount: Int) {
			patterns.reserveCapacity(literalCapacity + interpolationCount)
		}

		public mutating func appendLiteral(_ literal: String) {
			if !literal.isEmpty {
				patterns.append(Literal(literal))
			}
		}

		public mutating func appendInterpolation(_ newpatterns: Pattern...) {
			patterns.append(contentsOf: newpatterns)
		}
	}

	public init(stringLiteral value: String) {
		self.init(Literal(value))
	}

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
