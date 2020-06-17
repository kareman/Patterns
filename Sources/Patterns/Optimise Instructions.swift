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

	var canMoveAcross: Bool {
		switch self {
		case .elementEquals, .checkElement:
			return true
		default:
			return false
		}
	}
}

import SE0270_RangeSet

extension VMBacktrackEngine {
	static func optimiseInstructions(instructions: inout Instructions) {
		var movables = ContiguousArray<Instructions.Index>()[...]
		for i in instructions.indices {
			if instructions[i].isMovable {
				movables.append(i)
			} else if !movables.isEmpty, !instructions[i].canMoveAcross {
				let moved = instructions.moveSubranges(RangeSet(movables, within: instructions), to: i)
				for inst in moved {
					let oldPos = movables.popFirst()!
					switch instructions[inst] {
					case let .captureStart(name: name, atIndexOffset: offset):
						instructions[inst] = .captureStart(name: name, atIndexOffset: offset - (inst - oldPos))
					case let .captureEnd(atIndexOffset: offset):
						instructions[inst] = .captureEnd(atIndexOffset: offset - (inst - oldPos))
					case let .checkIndex(test, atIndexOffset: offset):
						instructions[inst] = .checkIndex(test, atIndexOffset: offset - (inst - oldPos))
					default:
						fatalError()
					}
				}
				assert(movables.isEmpty)
			}
		}
	}
}
