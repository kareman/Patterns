//
//  Literal.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

/// Matches a sequence of elements.
///
/// If empty, it will always succeed without consuming any input.
public struct Literal: Pattern {
	public let elements: Input

	public var description: String {
		#""\#(String(elements).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	/// Matches `sequence`.
	@inlinable
	public init<S: Sequence>(_ sequence: S) where S.Element == Pattern.Input.Element {
		self.elements = Pattern.Input(sequence)
	}

	/// Matches this character.
	@inlinable
	public init(_ character: Character) {
		self.init(String(character))
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) {
		instructions.append(contentsOf: elements.map(Instruction.elementEquals))
	}
}

extension Literal: ExpressibleByStringLiteral {
	@inlinable
	public init(stringLiteral value: StaticString) {
		self.init(String(describing: value))
	}
}
