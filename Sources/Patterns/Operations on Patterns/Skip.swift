//
//  Skip.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct Skip: Pattern {
	public var description: String { "Skip()" }

	public init() {}

	public func createInstructions(_ instructions: inout Instructions) throws {
		instructions.append(.skip)
		instructions.append(.jump(offset: 1)) // dummy
	}
}

import SE0270_RangeSet

extension MutableCollection where Self: RandomAccessCollection, Index == Int {
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
		let searchablesStartAt = skipIndex + 2
		switch self[searchablesStartAt] {
		case let .checkIndex(function, atIndexOffset: 0):
			self[skipIndex] = .search { input, index in
				input[index...].indices.first(where: { function(input, $0) })
					?? (function(input, input.endIndex) ? input.endIndex : nil)
			}
			self[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 1)
		case .checkIndex(_, atIndexOffset: _):
			fatalError("Cannot see a valid reason for a `.checkIndex` with a non-zero offset to be located right after a `.skip` instruction. Correct me if I'm wrong.")
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
				let cache = SearchCache(pattern: elements)
				self[skipIndex] = .search { input, index in
					input.range(of: elements, from: index, cache: cache)?.upperBound
				}
				self[searchablesStartAt] = .choice(offset: -1, atIndexOffset: (-elements.count) + 1)
				self[searchablesStartAt + 1] = .jump(offset: elements.count - 1)
			}
		default:
			self[skipIndex] = .choice(offset: 0, atIndexOffset: +1)
			self.placeSkipCommit(dummyIsAt: skipIndex + 1, startSearchFrom: skipIndex + 2)
			return
		}
		self.placeSkipCommit(dummyIsAt: skipIndex + 1, startSearchFrom: skipIndex + 3)
	}

	@usableFromInline
	mutating func placeSkipCommit<Input>(dummyIsAt dummyIndex: Index, startSearchFrom: Index)
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
			case let .jump(offset):
				i += offset
			case .elementEquals, .checkElement, .checkIndex, .moveIndex, .captureStart, .captureEnd, .call:
				i += 1
			case .commit, .choiceEnd, .return, .match, .skip, .search:
				moveSubranges(RangeSet(dummyIndex ..< (dummyIndex + 1)), to: i)
				self[i - 1] = .commit
				return
			case .fail, .openCall:
				fatalError()
			}
		}
	}
}
