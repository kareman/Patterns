//
//  Literal.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

public struct Literal: TextPattern {
	public let substring: Input

	public var description: String {
		return #""\#(String(substring).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	public init<S: Sequence>(_ sequence: S) where S.Element == TextPattern.Input.Element {
		self.substring = TextPattern.Input(sequence)
	}

	public init(_ character: Character) {
		self.init(String(character))
	}

	public func createInstructions() -> [Instruction<Input>] {
		return substring.map(Instruction.literal)
	}
}

extension Literal: ExpressibleByStringLiteral {
	public init(stringLiteral value: StaticString) {
		self.init(String(describing: value))
	}
}
