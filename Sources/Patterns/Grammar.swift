//
//  Grammar.swift
//
//
//  Created by Kåre Morstøl on 27/05/2020.
//

/// Allows for recursive patterns, also indirectly.
///
/// Define subpatterns using `<-`, like this arithmetic pattern:
/// ```
/// let g = Grammar { g in
///   g.all <- g.expr • !any
///   g.expr <- g.sum
///   g.sum <- g.product • (("+" / "-") • g.product)*
///   g.product <- g.power • (("*" / "/") • g.power)*
///   g.power <- g.value • ("^" • g.power)¿
///   g.value <- digit+ / "(" • g.expr • ")"
/// }
/// ```
/// This recognises e.g. "1+2-3*(4+3)"
///
/// - warning: Does not support left recursion:
///   ```
///   g.a <- g.a • g.b
///   ```
///   will lead to infinite recursion.
@dynamicMemberLookup
public class Grammar<Input: BidirectionalCollection>: Pattern where Input.Element: Hashable {
	/// Calls another subpattern in a grammar.
	public struct CallPattern: Pattern {
		/// The grammar that contains the subpattern being called.
		public let grammar: Grammar<Input>
		/// The name of the subpattern being called.
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

	/// All the subpatterns and their names.
	public internal(set) var patterns: [(name: String, pattern: AnyPattern)] = []

	/// The main subpattern, which will be called when this Grammar is being used.
	public var firstPattern: String? { patterns.first?.name }

	@inlinable
	public init() {}

	@inlinable
	public convenience init(_ closure: (Grammar) -> Void) {
		self.init()
		closure(self)
	}

	@inlinable
	/// Allows the use of e.g. `g.a` to refer to subpatterns.
	public subscript(dynamicMember name: String) -> CallPattern {
		CallPattern(grammar: self, name: name)
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		// We begin with a call to the first subpattern, followed by a jump to the end.
		// This enables this grammar to be used inside other patterns (including other grammars).

		let startIndex = instructions.endIndex
		instructions.append(
			.openCall(name: try firstPattern ?? Parser<Input>.PatternError.message("Grammar is empty.")))
		instructions.append(.jump(offset: .max)) // replaced later
		var callTable = [String: Range<Instructions.Index>]()

		// Create instructions for all subpatterns. Store their positions in `callTable`.
		for (name, pattern) in patterns {
			let startIndex = instructions.endIndex
			try pattern.createInstructions(&instructions)
			instructions.append(.return)
			guard (startIndex ..< instructions.endIndex).count > 1 else {
				throw Parser<Input>.PatternError.message("Pattern '\(name) <- \(pattern)' was empty.")
			}
			callTable[name] = startIndex ..< instructions.endIndex
		}

		// Replace all `.openCall` with `.call(offset)` and the correct offsets.
		for i in instructions.indices[startIndex...] {
			if case let .openCall(name) = instructions[i] {
				guard let subpatternRange = callTable[name] else {
					throw Parser<Input>.PatternError.message("Pattern '\(name)' was never defined with ´<-´ operator.")
				}
				// If the last non-dummy (i.e. not .choiceEnd) instruction in a subpattern is a call to itself we
				// perform a tail call optimisation by jumping directly instead.
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
	}

	public static func == <Input>(lhs: Grammar<Input>, rhs: Grammar<Input>) -> Bool {
		lhs.patterns.elementsEqual(rhs.patterns, by: { $0.name == $1.name && $0.pattern == $1.pattern })
	}
}

infix operator <-: AssignmentPrecedence

/// Used by grammars to define subpatterns with `g.a <- ...`.
public func <- <P: Pattern>(call: Grammar<P.Input>.CallPattern, pattern: P) {
	call.grammar.patterns.append((call.name, AnyPattern(pattern)))
}

/// In case of `g.name <- Capture(...)`, names the nameless Capture "name".
public func <- <P: Pattern>(call: Grammar<P.Input>.CallPattern, capture: Capture<P>) {
	let newPattern = capture.name == nil
		? Capture(name: call.name, capture.wrapped)
		: capture
	call.grammar.patterns.append((call.name, AnyPattern(newPattern)))
}
