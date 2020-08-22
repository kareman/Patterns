//
//  Skip.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

/// Skips 0 or more elements until a match for the next patterns is found.
///
/// ```swift
/// let s = Skip() • a
/// ```
/// is the same as `|S <- A / . <S>|` in standard PEG.
///
/// - note:
/// If `Skip` is at the end of a pattern, it just succeeds without consuming input. So it will be pointless.
///
/// But this works:
/// ```swift
/// let s = Skip()
/// let p = s • " "
/// ```
/// because here the `s` pattern is "inlined".
///
/// This, however, does not work:
/// ```swift
/// let g = Grammar { g in
///   g.nextSpace <- g.skip • " "
///   g.skip <- Skip()
/// }
/// ```
/// because in grammars the subexpressions are _called_, like functions, not "_inlined_", like Swift variables.
/// So the `Skip()` in `g.skip` can't tell what will come after it.
public struct Skip<Input: BidirectionalCollection>: Pattern where Input.Element: Hashable {
	public var description: String { "Skip()" }

	@inlinable
	public init() {}

	@inlinable
	public init() where Input == String {}

	@inlinable
	public func createInstructions(_ instructions: inout ContiguousArray<Instruction<Input>>) throws {
		instructions.append(.skip)
	}
}

import SE0270_RangeSet

extension ContiguousArray {
	/// Replaces all placeholder `.skip` instructions.
	@_specialize(where Input == String, Element == Instruction<String>) // doesn't happen automatically (swiftlang-1200.0.28.1).
	@_specialize(where Input == String.UTF8View, Element == Instruction<String.UTF8View>)
	@usableFromInline
	mutating func replaceSkips<Input>() where Element == Instruction<Input> {
		// `setupSkip(at: i)` adds 1 new instruction somewhere after `ì`, so we cant loop over self.indices directly.
		var i = self.startIndex
		while i < self.endIndex {
			switch self[i] {
			case .skip:
				self.setupSkip(at: i)
			default: break
			}
			self.formIndex(after: &i)
		}
	}

	/// Replaces the dummy `.skip` instruction at `skipIndex` with one that will search using the instructions
	/// right after `skipIndex`.
	///
	/// In other words we look at the instructions right after the .skip and see if they can be searched for
	/// efficiently.
	///
	/// Also places a .choice right after the search instruction replacing the .skip, and a corresponding .commit
	/// somewhere after that again. So if the search succeeds, but a later instruction fails, we can start a new
	/// search one step ahead from where the previous search succeeded.
	/// In the sub-pattern `Skip() • "abc" • letter • Skip() • "xyz"`, if "abc" succeeds, but there is no
	/// letter afterwards, we search for "abc" again from the "b". But if there is "abc" and another letter,
	/// we don't search for "abc" again because the next instruction is another .skip, and if we can't find "xyz"
	/// further on there's no point in searching for "abc" again.
	///
	/// See `placeSkipCommit` for more.
	@usableFromInline
	mutating func setupSkip<Input>(at skipIndex: Index) where Element == Instruction<Input> {
		let afterSkip = skipIndex + 1
		switch self[afterSkip] {
		case let .checkIndex(function, atIndexOffset: 0):
			self[skipIndex] = .search { input, index in
				input[index...].indices.first(where: { function(input, $0) })
					?? (function(input, input.endIndex) ? input.endIndex : nil)
			}
			self[afterSkip] = .choice(offset: -1, atIndexOffset: +1)
		case .checkIndex(_, atIndexOffset: _):
			// A `.checkIndex` will only have a non-zero offset if it has been moved by `moveMovablesForward`,
			// and that will never move anything beyond a `.skip`.
			fatalError("A `.checkIndex` with a non-zero offset can't be located right after a `.skip` instruction.")
		case let .checkElement(test):
			self[skipIndex] = .search { input, index in
				input[index...].firstIndex(where: test)
					.map(input.index(after:))
			}
			self[afterSkip] = .choice(offset: -1, atIndexOffset: 0)
		case .elementEquals:
			let elements: [Input.Element] = self[afterSkip...]
				.mapPrefix {
					switch $0 {
					case let .elementEquals(element):
						return element
					default:
						return nil
					}
				}
			if elements.count == 1 {
				self[skipIndex] = .search { input, index in
					input[index...].firstIndex(of: elements[0])
						.map(input.index(after:))
				}
				self[afterSkip] = .choice(offset: -1, atIndexOffset: 0)
			} else {
				// More than one literal, use Boyer–Moore–Horspool search.
				let cache = SearchCache(elements)
				self[skipIndex] = .search { input, index in
					input.range(of: cache, from: index)?.upperBound
				}
				self[afterSkip] = .choice(offset: -1, atIndexOffset: (-elements.count) + 1)
				self[afterSkip + 1] = .jump(offset: elements.count - 1)
			}
		default:
			// Could not find instructions to search for efficiently,
			// so we just try them and if they fail we move one step forward and try again.
			self[skipIndex] = .choice(offset: 0, atIndexOffset: +1)
			self.placeSkipCommit(startSearchFrom: skipIndex + 1)
			return
		}
		self.placeSkipCommit(startSearchFrom: skipIndex + 2)
	}

	/// Places a .commit after replacing a .skip .
	///
	/// Any instruction replacing a .skip will have a .choice right after it.
	/// We place the corresponding .commit as far after it as possible.
	/// As always we have to make sure that no pairs of corresponding .choice (or other instruction) and .commit
	/// intersect with any other pair.
	///
	/// So we have to jump over any optional repetition (`¿+*` and `.repeat(range)`) and any `/` choice patterns.
	/// All of them use the `.choice` instruction.
	/// If we are inside any of these we put the .commit at the end of our part of the pattern.
	@usableFromInline
	mutating func placeSkipCommit<Input>(startSearchFrom: Index) where Element == Instruction<Input> {
		var i = startSearchFrom
		loop: while true {
			switch self[i] {
			case let .choice(_, indexOffset) where indexOffset < 0:
				fatalError("Not implemented.")
			case let .choice(offset, _):
				// We jump over this entire sub-pattern.
				// If one step back there is a jump forwards, then it's a '/' pattern. So follow that jump too.
				if case let .jump(jumpOffset) = self[i + offset - 1], jumpOffset > 0 {
					i += offset - 1 + jumpOffset
				} else {
					i += offset
				}
			case let .jump(offset) where offset > 0: // If we jump backwards we are likely to enter an infinite loop.
				i += offset
			case .elementEquals, .checkElement, .checkIndex, .moveIndex, .captureStart, .captureEnd, .call, .jump:
				i += 1
			case .commit, .choiceEnd, .return, .match, .skip, .search, .fail:
				// This is as far as we can go.
				insertInstructions(.commit, at: i)
				return
			case .openCall:
				fatalError("`.openCall` instruction should have been replaced.")
			}
		}
	}

	/// Inserts `newInstructions` at `location`. Adjusts the offsets of the other instructions accordingly.
	///
	/// Since all offsets are relative to the positions of their instructions,
	/// if `location` lies between an instruction with an offset and where that offset leads to,
	/// the offset needs to be increased by the length of `newInstructions`.
	@usableFromInline
	mutating func insertInstructions<Input>(_ newInstructions: Element..., at location: Index)
		where Element == Instruction<Input> {
		insert(contentsOf: newInstructions, at: location)
		let insertedRange = location ..< (location + newInstructions.count + 1)
		// instruction ... location ... offsetTarget
		for i in startIndex ..< insertedRange.lowerBound {
			switch self[i] {
			case let .call(offset) where offset > (location - i):
				self[i] = .call(offset: offset + newInstructions.count)
			case let .jump(offset) where offset > (location - i):
				self[i] = .jump(offset: offset + newInstructions.count)
			case let .choice(offset, atIndexOffset) where offset > (location - i):
				self[i] = .choice(offset: offset + newInstructions.count, atIndexOffset: atIndexOffset)
			default:
				break
			}
		}
		// offsetTarget ... location ... instruction
		for i in insertedRange.upperBound ..< endIndex {
			switch self[i] {
			case let .call(offset) where offset < (location - i):
				self[i] = .call(offset: offset - newInstructions.count)
			case let .jump(offset) where offset < (location - i):
				self[i] = .jump(offset: offset - newInstructions.count)
			case let .choice(offset, atIndexOffset) where offset < (location - i):
				self[i] = .choice(offset: offset - newInstructions.count, atIndexOffset: atIndexOffset)
			default:
				break
			}
		}
	}
}
