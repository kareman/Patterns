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

		public func createInstructions() -> [Instruction<Input>] {
			[]
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

	public subscript(dynamicMember name: String) -> CallPattern {
		CallPattern(grammar: self, name: name)
	}

	public func createInstructions() -> [Instruction<Input>] {
		[]
	}
}

infix operator <-: AssignmentPrecedence

public func <- <P: Pattern>(call: Grammar.CallPattern, pattern: P) {
	call.grammar.patterns[call.name] = AnyPattern(pattern)
}

public func <- <P: Pattern>(call: Grammar.CallPattern, capture: Capture<P>) {
	let newPattern = AnyPattern(capture.name == nil ? Capture(name: call.name, capture.wrapped) : capture)
	call.grammar.patterns[call.name] = newPattern
}

private extension Capture {
	init(name: String? = nil, _ pattern: Wrapped?) {
		self.wrapped = pattern
		self.name = name
	}
}
