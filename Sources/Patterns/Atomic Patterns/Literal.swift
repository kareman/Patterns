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
public struct Literal<Input: BidirectionalCollection>: Pattern where Input.Element: Hashable {
	public let elements: Input

	public var description: String {
		#""\#(String(describing: elements).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	@inlinable
	public init(_ input: Input) {
		elements = input
	}

	/// Matches `sequence`.
	@inlinable
	public init<S: Sequence>(_ sequence: S) where S.Element == Input.Element, Input == String {
		self.elements = Input(sequence)
	}

	@inlinable
	public func createInstructions(_ instructions: inout ContiguousArray<Instruction<Input>>) {
		instructions.append(contentsOf: elements.map(Instruction<Input>.elementEquals))
	}
}

extension Literal where Input == String {
	/// Matches this character.
	@inlinable
	public init(_ character: Character) {
		self.init(String(character))
	}
}

// MARK: Create from string literal.

extension Literal: ExpressibleByUnicodeScalarLiteral where Input: LosslessStringConvertible {
	@inlinable
	public init(unicodeScalarLiteral value: StaticString) {
		elements = Input(String(describing: value))!
	}
}

extension Literal: ExpressibleByExtendedGraphemeClusterLiteral where Input: LosslessStringConvertible {
	public typealias ExtendedGraphemeClusterLiteralType = StaticString
}

extension Literal: ExpressibleByStringLiteral where Input: LosslessStringConvertible {
	@inlinable
	public init(stringLiteral value: StaticString) {
		elements = Input(String(describing: value))!
	}
}

extension String.UTF8View: LosslessStringConvertible {
	@inlinable
	public init?(_ description: String) {
		self = description.utf8
	}
}

extension String.UTF16View: LosslessStringConvertible {
	@inlinable
	public init?(_ description: String) {
		self = description.utf16
	}
}

extension String.UnicodeScalarView: LosslessStringConvertible {
	@inlinable
	public init?(_ description: String) {
		self = description.unicodeScalars
	}
}
