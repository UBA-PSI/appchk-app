import UIKit

// See: https://noahgilmore.com/blog/dark-mode-uicolor-compatibility/
extension UIColor {
	/// `.systemBackground ?? .white`
	static var sysBackground: UIColor { if #available(iOS 13.0, *) { return .systemBackground } else { return .white } }
	/// `.link ?? .systemBlue`
	static var sysLink: UIColor { if #available(iOS 13.0, *) { return .link } else { return .systemBlue } }
	
	/// `.label ?? .black`
	static var sysLabel: UIColor { if #available(iOS 13.0, *) { return .label } else { return .black } }
	/// `.secondaryLabel ?? rgba(60, 60, 67, 0.6)`
	static var sysLabel2: UIColor { if #available(iOS 13.0, *) { return .secondaryLabel } else { return .init(red: 60/255.0, green: 60/255.0, blue: 67/255.0, alpha: 0.6) } }
	/// `.tertiaryLabel ?? rgba(60, 60, 67, 0.3)`
	static var sysLabel3: UIColor { if #available(iOS 13.0, *) { return .tertiaryLabel } else { return .init(red: 60/255.0, green: 60/255.0, blue: 67/255.0, alpha: 0.3) } }
}

extension NSMutableAttributedString {
	func withColor(_ color: UIColor, fromBack: Int) -> Self {
		let l = length - fromBack
		let r = (l < 0) ? NSMakeRange(0, length) : NSMakeRange(l, fromBack)
		self.addAttribute(.foregroundColor, value: color, range: r)
		return self
	}
}
