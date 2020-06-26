import UIKit

extension UIFont {
	func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
		UIFont(descriptor: fontDescriptor.withSymbolicTraits(traits)!, size: 0) // keep size as is
    }
    func bold() -> UIFont { withTraits(traits: .traitBold) }
    func italic() -> UIFont { withTraits(traits: .traitItalic) }
	func monoSpace() -> UIFont {
		let traits = fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any] ?? [:]
		let weight = (traits[.weight] as? CGFloat) ?? UIFont.Weight.regular.rawValue
		return .monospacedDigitSystemFont(ofSize: pointSize, weight: .init(rawValue: weight))
	}
}

extension NSAttributedString {
	static func image(_ img: UIImage) -> Self {
		let att = NSTextAttachment()
		att.image = img
		return self.init(attachment: att)
	}
}

extension NSMutableAttributedString {
	static private var def: UIFont = .preferredFont(forTextStyle: .body)
	
	func normal(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: .preferredFont(forTextStyle: style)) }
	func bold(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: UIFont.preferredFont(forTextStyle: style).bold()) }
	func italic(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: UIFont.preferredFont(forTextStyle: style).italic()) }
	
	func h1(_ str: String) -> Self { normal(str, .title1) }
	func h2(_ str: String) -> Self { normal(str, .title2) }
	func h3(_ str: String) -> Self { normal(str, .title3) }
	
	private func append(_ str: String, withFont: UIFont) -> Self {
		append(NSAttributedString(string: str, attributes: [
			.font : withFont,
			.foregroundColor : UIColor.sysLabel
		]))
		return self
	}
	
	func centered(_ content: NSAttributedString) -> Self {
		let before = length
		append(content)
		let ps = NSMutableParagraphStyle()
		ps.alignment = .center
		addAttribute(.paragraphStyle, value: ps, range: .init(location: before, length: content.length))
		return self
	}
}
