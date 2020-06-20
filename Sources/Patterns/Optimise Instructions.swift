//
//  Optimise Instructions.swift
//
//  Created by Kåre Morstøl on 17/06/2020.
//

private extension Instruction {
	var isMovable: Bool {
		switch self {
		case .checkIndex, .captureStart, .captureEnd:
			return true
		default:
			return false
		}
	}

	var stopsMovables: Bool {
		switch self {
		case .elementEquals, .checkElement:
			return false
		default:
			return true
		}
	}
}

import SE0270_RangeSet

extension MutableCollection where Self: RandomAccessCollection, Index == Int {
	@usableFromInline
	mutating func moveMovablesForward<Input>() where Element == Instruction<Input> {
		var movables = ContiguousArray<Index>()[...]
		for i in indices {
			if self[i].isMovable {
				movables.append(i)
			} else if !movables.isEmpty, self[i].stopsMovables {
				let moved = moveSubranges(RangeSet(movables, within: self), to: i)
				var checkIndexIndices = RangeSet<Index>()
				for (movedIndex, oldPosition) in zip(moved, movables) {
					let distanceMoved = (movedIndex - oldPosition)
					switch self[movedIndex] {
					case let .captureStart(name, offset):
						self[movedIndex] = .captureStart(name: name, atIndexOffset: offset - distanceMoved)
					case let .captureEnd(offset):
						self[movedIndex] = .captureEnd(atIndexOffset: offset - distanceMoved)
					case let .checkIndex(test, offset):
						self[movedIndex] = .checkIndex(test, atIndexOffset: offset - distanceMoved)
						checkIndexIndices.insert(movedIndex, within: self)
					default:
						fatalError()
					}
				}
				movables.removeAll()

				// All `.checkIndex` should be first.
				moveSubranges(checkIndexIndices, to: moved.lowerBound)
			}
		}
	}
}
