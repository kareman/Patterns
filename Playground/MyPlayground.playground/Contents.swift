// Playground generated with 🏟 Arena (https://github.com/finestructure/arena)
// ℹ️ If running the playground fails with an error "no such module ..."
//    go to Product -> Build to re-trigger building the SPM package.
// ℹ️ Please restart Xcode if autocomplete is not working.

import Patterns
import PlaygroundSupport
import SwiftUI

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

The top expression is called first. • !any means it must match the entire string, because only at the end of the string is there no characters. If you want to match multiple arithmetic expressions in a string, comment out the first expression. Grammars use dynamic properties so there is no auto-completion for the expression names.

"""

let view = try ParserView(text: text, pattern: arithmetic)
let size = NSSize(width: 600, height: 600)
let hosting = NSHostingController(rootView: view)
hosting.view.frame.size = size
PlaygroundPage.current.setLiveView(hosting)
