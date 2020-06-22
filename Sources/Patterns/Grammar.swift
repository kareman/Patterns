//
//  Grammar.swift
//
//
//  Created by Kåre Morstøl on 27/05/2020.
//

@dynamicMemberLookup
public class Grammar: Pattern {
	public struct CallPattern: Pattern {
		public var description: String { "g." + name }
		public let grammar: Grammar
		public let name: String

		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.openCall(name: name))
		}
	}

	public var description: String { "Grammar" }

	public fileprivate(set) var patterns: [String: AnyPattern] = [:] {
		didSet {
			if firstPattern == nil {
				firstPattern = patterns.first?.key
			}
		}
	}

	public fileprivate(set) var firstPattern: String?

	public init() {}

	public convenience init(_ closure: (Grammar) -> Void) {
		self.init()
		closure(self)
	}

	public subscript(dynamicMember name: String) -> CallPattern {
		CallPattern(grammar: self, name: name)
	}

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
	call.grammar.patterns[call.name] = AnyPattern(pattern)
}

public func <- <P: Pattern>(call: Grammar.CallPattern, capture: Concat<Concat<CaptureStart, P>, CaptureEnd>) {
	let newPattern = capture.left.left.name == nil
		? (CaptureStart(name: call.name) • capture.left.right • capture.right)
		: capture
	call.grammar.patterns[call.name] = AnyPattern(newPattern)
}
