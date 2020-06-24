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
			.openCall(name: try firstPattern ?? Parser<Input>.InitError.message("Grammar is empty")))
		instructions.append(.jump(offset: .max)) // replaced later
		var callTable = [String: Instructions.Index]()
		for (name, pattern) in patterns {
			callTable[name] = instructions.endIndex
			try pattern.createInstructions(&instructions)
			precondition(callTable[name] != instructions.endIndex,
			             "Pattern '\(name) <- \(pattern)' was empty")
			instructions.append(.return)
		}

		for i in instructions.indices[startIndex...] {
			if case let .openCall(name) = instructions[i] {
				let address = try callTable[name]
					?? Parser<Input>.InitError.message("Pattern '\(name)' was never defined with ´<-´ operator.")
				instructions[i] = .call(offset: address - i)
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
