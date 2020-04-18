import UIKit

struct QuickUI {
	
	static func button(_ title: String, target: Any? = nil, action: Selector? = nil) -> UIButton {
		let x = UIButton(type: .roundedRect)
		x.setTitle(title, for: .normal)
		x.titleLabel?.font = .preferredFont(forTextStyle: .body)
		x.sizeToFit()
		if let a = action { x.addTarget(target, action: a, for: .touchUpInside) }
		if #available(iOS 10.0, *) {
			x.titleLabel?.adjustsFontForContentSizeCategory = true
		}
		return x
	}
	
	static func image(_ img: UIImage?, frame: CGRect = CGRect.zero) -> UIImageView {
		let x = UIImageView(frame: frame)
		x.contentMode = .scaleAspectFit
		x.image = img
		return x
	}
	
	static func text(_ str: String, frame: CGRect = CGRect.zero) -> UITextView {
		let x = UITextView(frame: frame)
		x.font = .preferredFont(forTextStyle: .body) // .systemFont(ofSize: UIFont.systemFontSize)
		x.isSelectable = false
		x.isEditable = false
		x.text = str
		if #available(iOS 10.0, *) {
			x.adjustsFontForContentSizeCategory = true
		}
		return x
	}
	
	static func text(attributed: NSAttributedString, frame: CGRect = CGRect.zero) -> UITextView {
		let txt = self.text("", frame: frame)
		txt.attributedText = attributed
		return txt
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
			.foregroundColor : UIColor.sysFg
		]))
		return self
	}
}


extension UIFont {
	func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
		UIFont(descriptor: fontDescriptor.withSymbolicTraits(traits)!, size: 0) // keep size as is
    }
    func bold() -> UIFont { withTraits(traits: .traitBold) }
    func italic() -> UIFont { withTraits(traits: .traitItalic) }
}
