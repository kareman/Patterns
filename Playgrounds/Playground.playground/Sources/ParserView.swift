//
//  ContentView.swift
//  PlaygroundView
//
//  Created by Kåre Morstøl on 13/06/2020.
//

import AppKit
import Patterns
import SwiftUI

public struct ParserView: View {
	let attributedString: NSMutableAttributedString
	let captureColors: [NSAttributedString]

	init() {
		attributedString = NSMutableAttributedString()
		captureColors = []
	}

	public init<P: Patterns.Pattern>(text: String, pattern: P) throws where P.Input == String {
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
			MultiLineLabel {
				$0.textStorage!.setAttributedString(self.attributedString)
			}
		}.padding(10)
	}
}

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

//
//  General.swift
//  PlaygroundView
//
//  Created by Kåre Morstøl on 13/06/2020.
//

import AppKit
import Patterns

typealias Attributes = [NSAttributedString.Key: Any]

let defaultTextAttributes: Attributes = {
	let defaultTextSize = CGFloat(14)
	let font = NSFont(name: "Menlo", size: defaultTextSize)
		?? NSFont.monospacedDigitSystemFont(ofSize: defaultTextSize, weight: .regular)
	return [.font: font, .foregroundColor: NSColor.textColor, .backgroundColor: NSColor.textBackgroundColor]
}()

let defaultCapturedAttributes =
	[NSColor.systemGreen, .systemPurple, .systemOrange, .systemTeal, .systemBlue, .systemRed]
	.map { color -> Attributes in
		var attribs = defaultTextAttributes
		attribs[.backgroundColor] = color.withAlphaComponent(0.5)
		return attribs
	}

func adorn<S: Sequence>(_ string: String, matches: S) -> (NSMutableAttributedString, [String: Attributes])
	where S.Element == Parser<String>.Match {
	var capturedAttributes = defaultCapturedAttributes.repeatForever().makeIterator()
	let attributedString = NSMutableAttributedString(string: string, attributes: defaultTextAttributes)
	var captureColors = [String: Attributes]()
	for match in matches {
		for (name, range) in match.captures {
			let nsrange = NSRange(range, in: string)
			if captureColors[name ?? "unnamed"] == nil { captureColors[name ?? "unnamed"] = capturedAttributes.next()! }
			let attributes = captureColors[name ?? "unnamed"]
			attributedString.setAttributes(attributes, range: nsrange)
		}
	}

	return (attributedString, captureColors)
}

extension Sequence {
	func repeatForever() -> LazySequence<UnfoldSequence<Element, Iterator>> {
		sequence(state: self.makeIterator()) { (iterator: inout Iterator) -> Element? in
			iterator.next() ?? {
				iterator = self.makeIterator()
				return iterator.next()
			}()
		}.lazy
	}
}

extension NSAttributedString {
	var nsRange: NSRange { NSRange(location: 0, length: self.length) }
}

import AppKit
import SwiftUI

public struct MultiLineLabel: NSViewRepresentable {
	public typealias TheUIView = NSTextView
	var configuration = { (view: TheUIView) in }

	public func makeNSView(context: Context) -> TheUIView {
		let view = TheUIView()
		view.isEditable = false
		return view
	}

	public func updateNSView(_ nsView: TheUIView, context: Context) {
		configuration(nsView)
	}
}

public struct SingleLineLabel: NSViewRepresentable {
	public typealias TheUIView = NSTextField
	let content: NSAttributedString

	public func makeNSView(context: Context) -> TheUIView {
		let view = TheUIView(labelWithAttributedString: content)
		view.isEditable = false
		//view.alignment = .center
		return view
	}

	public func updateNSView(_ nsView: TheUIView, context: Context) {}
}

import PlaygroundSupport

public func showParserView<P: Patterns.Pattern>(ofSize size: NSSize = NSSize(width: 600, height: 600), pattern: P, withText text: String) throws where P.Input == String {
	let view = try ParserView(text: text, pattern: pattern)
	let hosting = NSHostingController(rootView: view)
	hosting.view.frame.size = size
	PlaygroundPage.current.setLiveView(hosting)
}
