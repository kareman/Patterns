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

extension VMBacktrackEngine {
	static func replaceSkips(instructions: inout Instructions) {
		for i in instructions.indices {
			switch instructions[i] {
			case .skip:
				Self.setupSkip(&instructions, at: i)
			default:
				_ = 1
			}
		}
	}

	static func setupSkip(_ instructions: inout Instructions, at skipIndex: Instructions.Index) {
		let searchablesStartAt = instructions.index(skipIndex, offsetBy: 2)
		switch instructions[searchablesStartAt] {
		case let .checkIndex(function, atIndexOffset: 0):
			instructions[skipIndex] = .search { input, index in
				input[index...].indices.first(where: { function(input, $0) })
					?? (function(input, input.endIndex) ? input.endIndex : nil)
			}
			instructions[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 1)
		case let .checkElement(test):
			instructions[skipIndex] = .search { input, index in
				input[index...].firstIndex(where: test)
					.map(input.index(after:))
			}
			instructions[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 0)
		case .elementEquals:
			// TODO: mapWhile
			let elements: [Input.Element] = instructions[searchablesStartAt...]
				.prefix(while: { if case .elementEquals = $0 { return true } else { return false } })
				.map { if case let .elementEquals(c) = $0 { return c } else { fatalError() } }
			if elements.count == 1 {
				instructions[skipIndex] = .search { input, index in
					input[index...].firstIndex(of: elements[0])
						.map(input.index(after:))
				}
				instructions[searchablesStartAt] = .choice(offset: -1, atIndexOffset: 0)
			} else {
				let cache = SearchCache(pattern: elements)
				instructions[skipIndex] = .search { input, index in
					input.range(of: elements, from: index, cache: cache)?.upperBound
				}
				instructions[searchablesStartAt] = .choice(offset: -1, atIndexOffset: (-elements.count) + 1)
				instructions[searchablesStartAt + 1] = .jump(offset: elements.count - 1)
			}
		default:
			instructions[skipIndex] = .choice(offset: 0, atIndexOffset: +1)
			Self.placeSkipCommit(&instructions, skipIsAt: skipIndex, startSearchFrom: skipIndex + 2)
			return
		}
		Self.placeSkipCommit(&instructions, skipIsAt: skipIndex, startSearchFrom: skipIndex + 3)
	}

	static func placeSkipCommit(_ instructions: inout Instructions, skipIsAt skipindex: Instructions.Index, startSearchFrom: Instructions.Index) {
		var i = startSearchFrom
		loop: while true {
			switch instructions[i] {
			case let .choice(offset: _, atIndexOffset: indexOffset) where indexOffset < 0:
				fatalError()
			case let .choice(offset, _):
				// Follow every choice offset.
				// If one step back there is a jump forwards, then it's a '/' operation. So follow it too.
				if case let .jump(jumpOffset) = instructions[i + offset - 1], jumpOffset > 0 {
					i += offset - 1 + jumpOffset
				} else {
					i += offset
				}
			case let .jump(offset):
				i += offset
			case .elementEquals, .checkElement, .checkIndex, .moveIndex, .captureStart, .captureEnd, .call:
				i += 1
			case .commit, .choiceEnd, .return, .match, .skip, .search:
				let dummyIndex = skipindex + 1
				instructions.moveSubranges(RangeSet(dummyIndex ..< (dummyIndex + 1)), to: i)
				instructions[i - 1] = .commit
				return
			case .fail, .openCall:
				fatalError()
			}
		}
	}
}
