//
//  Literal.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

import Foundation

/// Matches these exact elements.
///
/// If empty, it will always succeed without consuming any input.
public struct Literal: Pattern {
	public let elements: Input

	public var description: String {
		#""\#(String(elements).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	public init<S: Sequence>(_ sequence: S) where S.Element == Pattern.Input.Element {
		self.elements = Pattern.Input(sequence)
	}

	public init(_ character: Character) {
		self.init(String(character))
	}

	public func createInstructions(_ instructions: inout Instructions) {
		instructions.append(contentsOf: elements.map(Instruction.elementEquals))
	}
}

extension Literal: ExpressibleByStringLiteral {
	public init(stringLiteral value: StaticString) {
		self.init(String(describing: value))
	}
}
