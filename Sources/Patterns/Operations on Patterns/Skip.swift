//
//  Skip.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

/// Skips 0 or more elements until a match for the next patterns are found.
///
/// If this is at the end of a pattern, it skips to the end of input.
public struct Skip<Input: BidirectionalCollection>: Pattern where Input.Element: Hashable {
	public var description: String { "Skip()" }

	public init() {}

	@inlinable
	public func createInstructions(_ instructions: inout Self.Instructions) throws {
		instructions.append(.skip)
	}
}

import SE0270_RangeSet

extension MutableCollection where Self: RandomAccessCollection, Self: RangeReplaceableCollection, Index == Int {
	@usableFromInline
	mutating func replaceSkips<Input>() where Element == Instruction<Input> {
		for i in self.indices {
			switch self[i] {
			case .skip:
				self.setupSkip(at: i)
			default: break
			}
		}
	}

	@usableFromInline
	mutating func setupSkip<Input>(at skipIndex: Index) where Element == Instruction<Input> {
		let searchablesStartAt = skipIndex + 1
		switch self[searchablesStartAt] {
		case let .checkIndex(function, atIndexOffset: 0):
			self[skipIndex] = .search { input, index in
				input[index...].indices.first(where: { function(input, $0) })
					?? (function(input, input.endIndex) ? input.endIndex : nil)
			}
			self[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 1)
		case .checkIndex(_, atIndexOffset: _):
			fatalError("Cannot see a valid reason for a `.checkIndex` with a non-zero offset to be located right after a `.skip` instruction.") // Correct me if I'm wrong.
		case let .checkElement(test):
			self[skipIndex] = .search { input, index in
				input[index...].firstIndex(where: test)
					.map(input.index(after:))
			}
			self[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 0)
		case .elementEquals:
			let elements: [Input.Element] = self[searchablesStartAt...]
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
				self[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 0)
			} else {
				let cache = SearchCache(elements)
				self[skipIndex] = .search { input, index in
					input.range(of: cache, from: index)?.upperBound
				}
				self[searchablesStartAt] = .choice(offset: -1, atIndexOffset: (-elements.count) + 1)
				self[searchablesStartAt + 1] = .jump(offset: elements.count - 1)
			}
		default:
			self[skipIndex] = .choice(offset: 0, atIndexOffset: +1)
			self.placeSkipCommit(startSearchFrom: skipIndex + 1)
			return
		}
		self.placeSkipCommit(startSearchFrom: skipIndex + 2)
	}

	@usableFromInline
	mutating func placeSkipCommit<Input>(startSearchFrom: Index)
		where Element == Instruction<Input> {
		var i = startSearchFrom
		loop: while true {
			switch self[i] {
			case let .choice(_, indexOffset) where indexOffset < 0:
				fatalError("Not implemented.")
			case let .choice(offset, _):
				// Follow every choice offset.
				// If one step back there is a jump forwards, then it's a '/' operation. So follow it too.
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
				insertInstructions(.commit, at: i)
				return
			case .openCall:
				fatalError()
			}
		}
	}

	/// Inserts new instructions at `location`. Adjusts the offsets of the other instructions accordingly.
	@usableFromInline
	mutating func insertInstructions<Input>(_ newInstructions: Element..., at location: Index)
		where Element == Instruction<Input> {
		insert(contentsOf: newInstructions, at: location)
		let insertedRange = location ..< (location + newInstructions.count + 1)
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
