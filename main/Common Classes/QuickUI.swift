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
