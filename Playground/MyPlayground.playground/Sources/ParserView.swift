//
//  ContentView.swift
//  PlaygroundView
//
//  Created by Kåre Morstøl on 13/06/2020.
//

import AppKit
import SwiftUI

public struct ParserView: View {
	let attributedString: NSMutableAttributedString
	let captureColors: [NSAttributedString]

	init() {
		attributedString = NSMutableAttributedString()
		captureColors = []
	}

	public init<P: Patterns.Pattern>(text: String, pattern: P) throws {
		let parser = try Parser(search: pattern)
		let matches = parser.matches(in: text)
		let result = adorn(text, matches: matches)
		self.attributedString = result.0
		self.captureColors = result.1.map {
			NSAttributedString(string: $0.key, attributes: $0.value)
		}
	}

	public var body: some View {
		VStack {
			HStack {
				Text("Captures: ")
				ForEach(captureColors, id: \.hashValue) { name in
					SingleLineLabel(content: name)
				}
			}
			Label {
				$0.textStorage!.setAttributedString(self.attributedString)
			}
		}.padding(10)
	}
}

import Patterns

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		let text = "This is a point: (43,7), so is (0, 5). But my final point is (3,-1)."
		let number = ("+" / "-" / "") • digit+
		let point = "(" • Capture(name: "x", number)
			• "," • " "¿ • Capture(name: "y", number) • ")"

		return try! ParserView(text: text, pattern: point)
	}
}

struct ContentView_Previews2: PreviewProvider {
	static var previews: some View {
		let arithmetic = Grammar { g in
			//g.all     <- g.expr • !any
			g.expr <- g.sum
			g.sum <- g.product • (Capture(name: "sum", "+" / "-") • g.product)*
			g.product <- g.power • (Capture(name: "product", "*" / "/") • g.power)*
			g.power <- g.value • (Capture(name: "power", "^") • g.power)¿
			g.value <- Capture(name: "value", digit+) / "(" • g.expr • ")"
		}

		let text = """
		This will parse expressions like "1+2-3^(4*3)/2".

		The top expression is called first. • !any means it must match the entire string, because only at the end of the string is there no characters. If you want to match multiple arithmetic expressions in a string, comment out the first expression. Grammars use dynamic properties so there is no auto-completion for the expression names.

		This will parse expressions like "1+2-3^(4*3)/2".

		The top expression is called first. • !any means it must match the entire string, because only at the end of the string is there no characters. If you want to match multiple arithmetic expressions in a string, comment out the first expression. Grammars use dynamic properties so there is no auto-completion for the expression names.
		This will parse expressions like "1+2-3^(4*3)/2".

		The top expression is called first. • !any means it must match the entire string, because only at the end of the string is there no characters. If you want to match multiple arithmetic expressions in a string, comment out the first expression. Grammars use dynamic properties so there is no auto-completion for the expression names.
		This will parse expressions like "1+2-3^(4*3)/2".

		The top expression is called first. • !any means it must match the entire string, because only at the end of the string is there no characters. If you want to match multiple arithmetic expressions in a string, comment out the first expression. Grammars use dynamic properties so there is no auto-completion for the expression names.

		"""
		return try! ParserView(text: text, pattern: arithmetic)
	}
}
