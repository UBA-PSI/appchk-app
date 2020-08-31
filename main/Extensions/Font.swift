import UIKit

extension UIFont {
	func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
		UIFont(descriptor: fontDescriptor.withSymbolicTraits(traits)!, size: 0) // keep size as is
    }
    func bold() -> UIFont { withTraits(traits: .traitBold) }
    func italic() -> UIFont { withTraits(traits: .traitItalic) }
    func boldItalic() -> UIFont { withTraits(traits: [.traitBold, .traitItalic]) }
	func monoSpace() -> UIFont {
		let traits = fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any] ?? [:]
		let weight = (traits[.weight] as? CGFloat) ?? UIFont.Weight.regular.rawValue
		return .monospacedDigitSystemFont(ofSize: pointSize, weight: .init(rawValue: weight))
	}
}

extension NSMutableAttributedString {
	convenience init(image: UIImage, centered: Bool = false) {
		self.init()
		let att = NSTextAttachment()
		att.image = image
		append(.init(attachment: att))
		if centered {
			let ps = NSMutableParagraphStyle()
			ps.alignment = .center
			addAttribute(.paragraphStyle, value: ps, range: .init(location: 0, length: length))
		}
	}
}

extension NSMutableAttributedString {
	@discardableResult func normal(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: .preferredFont(forTextStyle: style)) }
	@discardableResult func bold(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: UIFont.preferredFont(forTextStyle: style).bold()) }
	@discardableResult func italic(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: UIFont.preferredFont(forTextStyle: style).italic()) }
	@discardableResult func boldItalic(_ str: String, _ style: UIFont.TextStyle = .body) -> Self { append(str, withFont: UIFont.preferredFont(forTextStyle: style).boldItalic()) }
	
	@discardableResult func h1(_ str: String) -> Self { normal(str, .title1) }
	@discardableResult func h2(_ str: String) -> Self { normal(str, .title2) }
	@discardableResult func h3(_ str: String) -> Self { normal(str, .title3) }
	
	private func append(_ str: String, withFont: UIFont) -> Self {
		append(NSAttributedString(string: str, attributes: [
			.font : withFont,
			.foregroundColor : UIColor.sysLabel
		]))
		return self
	}
}
