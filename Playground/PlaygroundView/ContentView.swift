//
//  ContentView.swift
//  PlaygroundView
//
//  Created by Kåre Morstøl on 13/06/2020.
//

import AppKit
import SwiftUI

struct Label: NSViewRepresentable {
	typealias TheUIView = NSTextView
	fileprivate var configuration = { (view: TheUIView) in }

	func makeNSView(context: Context) -> TheUIView {
		let view = TheUIView()
		view.isEditable = false
		return view
	}

	func updateNSView(_ nsView: TheUIView, context: Context) {
		configuration(nsView)
	}
}

struct ContentView: View {
	let attributedString: NSMutableAttributedString

	init() { attributedString = NSMutableAttributedString() }

	init<P: Patterns.Pattern>(text: String, pattern: P) throws {
		let parser = try Parser(search: pattern)
		let matches = parser.matches(in: text)
		self.attributedString = adorn(text, matches: matches)
	}

	var body: some View {
		Label {
			$0.textStorage!.setAttributedString(self.attributedString)
		}
	}
}

import Patterns

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		let text = "This is a point: (43,7), so is (0, 5). But my final point is (3,-1)."
		let number = ("+" / "-" / "") • digit+
		let point = "(" • Capture(name: "x", number)
			• "," • " "¿ • Capture(name: "y", number) • ")"

		return try! ContentView(text: text, pattern: point)
	}
}
