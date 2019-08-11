//
//  StringInterpolation.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 11/08/2019.
//

extension Patterns: ExpressibleByStringInterpolation {
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
		self.init(Literal(value))
	}

	public init(stringInterpolation: StringInterpolation) {
		self.init(stringInterpolation.patterns)
	}
}
