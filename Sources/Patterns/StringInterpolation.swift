//
//  StringInterpolation.swift
//  Patterns
//
//  Created by Kåre Morstøl on 11/08/2019.
//

extension ConcatenationPattern: ExpressibleByStringInterpolation {
	public struct StringInterpolation: StringInterpolationProtocol {
		var patterns = [TextPattern]()

		public init(literalCapacity: Int, interpolationCount: Int) {
			patterns.reserveCapacity(literalCapacity + interpolationCount)
		}

		public mutating func appendLiteral(_ literal: String) {
			if !literal.isEmpty {
				patterns.append(Literal(literal))
			}
		}

		public mutating func appendInterpolation(_ newpatterns: TextPattern...) {
			patterns.append(contentsOf: newpatterns)
		}
	}

	public init(stringLiteral value: String) {
		self.init(first: Literal(value), second: Literal(""))
	}

	public init(stringInterpolation: StringInterpolation) {
		var patterns = stringInterpolation.patterns[...]
		guard let first = patterns.popFirst() else {
			self.init(first: Literal(""), second: Literal(""))
			return
		}
		guard let second = patterns.popFirst() else {
			self.init(first: first, second: Literal(""))
			return
		}
		var result = first • second
		while let next = patterns.popFirst() {
			result = result • next
		}
		self = result
	}
}
