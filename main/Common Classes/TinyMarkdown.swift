import UIKit

struct TinyMarkdown {
	/// Load markdown file and run through a (very) simple parser (see below).
	/// - Parameters:
	///   - filename: Will automatically append `.md` extension
	///   - replacements: Replace a single occurrence of search string with an attributed replacement.
	static func load(_ filename: String, replacements: [String : NSMutableAttributedString] = [:]) -> UITextView {
		let url = Bundle.main.url(forResource: filename, withExtension: "md")!
		let str = NSMutableAttributedString(withMarkdown: try! String(contentsOf: url))
		for (key, val) in replacements {
			guard let r = str.string.range(of: key) else {
				QLog.Debug("WARN: markdown key '\(key)' does not exist in \(filename)")
				continue
			}
			str.replaceCharacters(in: NSRange(r, in: str.string), with: val)
		}
		return QuickUI.text(attributed: str)
	}
}

extension NSMutableAttributedString {
	/// Supports only: `#h1`, `##h2`, `###h3`, `_italic_`, `__bold__`, `___boldItalic___`
	convenience init(withMarkdown content: String) {
		self.init()
		let emph = try! NSRegularExpression(pattern: #"(?<=(^|\W))(_{1,3})(\S|\S.*?\S)\2"#, options: [])
		beginEditing()
		content.enumerateLines { (line, _) in
			if line.starts(with: "#") {
				var h = 0
				for char in line {
					if char == "#" { h += 1 }
					else { break }
				}
				var line = line
				line.removeFirst(h)
				line = line.trimmingCharacters(in: CharacterSet(charactersIn: " "))
				switch h {
				case 1: self.h1(line + "\n")
				case 2: self.h2(line + "\n")
				default: self.h3(line + "\n")
				}
			} else {
				let nsline = line as NSString
				let range = NSRange(location: 0, length: nsline.length)
				var i = 0
				for x in emph.matches(in: line, options: [], range: range) {
					let r = x.range
					self.normal(nsline.substring(from: i, to: r.location))
					i = r.upperBound
					let before = nsline.substring(with: r)
					let after = before.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
					switch (before.count - after.count) / 2 {
					case 1: self.italic(after)
					case 2: self.bold(after)
					default: self.boldItalic(after)
					}
				}
				if i < range.length {
					self.normal(nsline.substring(from: i, to: range.length) + "\n")
				} else {
					self.normal("\n")
				}
			}
		}
		endEditing()
	}
}
