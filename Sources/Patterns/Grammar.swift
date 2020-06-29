//
//  Grammar.swift
//
//
//  Created by Kåre Morstøl on 27/05/2020.
//

@dynamicMemberLookup
public class Grammar: Pattern {
	public struct CallPattern: Pattern {
		public let grammar: Grammar
		public let name: String
		public var description: String { "<\(name)>" }

		@inlinable
		init(grammar: Grammar, name: String) {
			self.grammar = grammar
			self.name = name
		}

		@inlinable
		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.openCall(name: name))
		}
	}

	public var description: String { "Grammar" } // TODO:

	public internal(set) var patterns: [(name: String, pattern: AnyPattern)] = []

	public var firstPattern: String? { patterns.first?.name }

	@inlinable
	public init() {}

	@inlinable
	public convenience init(_ closure: (Grammar) -> Void) {
		self.init()
		closure(self)
	}

	@inlinable
	public subscript(dynamicMember name: String) -> CallPattern {
		CallPattern(grammar: self, name: name)
	}

	@inlinable
	public func createInstructions(_ finalInstructions: inout Instructions) throws {
		var instructions = finalInstructions
		let startIndex = instructions.endIndex
		instructions.append(
			.openCall(name: try firstPattern ?? Parser<Input>.InitError.message("Grammar is empty.")))
		instructions.append(.jump(offset: .max)) // replaced later
		var callTable = [String: Range<Instructions.Index>]()
		for (name, pattern) in patterns {
			let startIndex = instructions.endIndex
			try pattern.createInstructions(&instructions)
			instructions.append(.return)
			guard (startIndex ..< instructions.endIndex).count > 1 else {
				throw Parser<Input>.InitError.message("Pattern '\(name) <- \(pattern)' was empty.")
			}
			callTable[name] = startIndex ..< instructions.endIndex
		}

		for i in instructions.indices[startIndex...] {
			if case let .openCall(name) = instructions[i] {
				guard let subpatternRange = callTable[name] else {
					throw Parser<Input>.InitError.message("Pattern '\(name)' was never defined with ´<-´ operator.")
				}
				// If the last non-dummy (often .choiceEnd) instruction in a subpattern is a call to itself we perform
				// a tail call optimisation by jumping directly instead.
				// The very last instruction is a .return, so skip that.
				if subpatternRange.upperBound - 2 == i
					|| (subpatternRange.upperBound - 3 == i && instructions[i + 1].doesNotDoAnything) {
					instructions[i] = .jump(offset: subpatternRange.lowerBound - i)
				} else {
					instructions[i] = .call(offset: subpatternRange.lowerBound - i)
				}
			}
		}
		instructions[startIndex + 1] = .jump(offset: instructions.endIndex - startIndex - 1)

		finalInstructions = instructions
	}
}

infix operator <-: AssignmentPrecedence

public func <- <P: Pattern>(call: Grammar.CallPattern, pattern: P) {
	call.grammar.patterns.append((call.name, AnyPattern(pattern)))
}

public func <- <P: Pattern>(call: Grammar.CallPattern, capture: Capture<P>) {
	let newPattern = capture.name == nil
		? Capture(name: call.name, capture.wrapped)
		: capture
	call.grammar.patterns.append((call.name, AnyPattern(newPattern)))
}
