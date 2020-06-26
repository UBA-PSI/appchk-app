import UIKit

struct QLog {
	private init() {}
	static func m(_ message: String) { write("", message) }
	static func Info(_ message: String) { write("[INFO] ", message) }
#if DEBUG
	static func Debug(_ message: String) { write("[DEBUG] ", message) }
#else
	static func Debug(_ _: String) {}
#endif
	static func Error(_ message: String) { write("[ERROR] ", message) }
	static func Warning(_ message: String) { write("[WARN] ", message) }
	private static func write(_ tag: String, _ message: String) {
		print(String(format: "%1.3f %@%@", Date().timeIntervalSince1970, tag, message))
	}
}

// See: https://noahgilmore.com/blog/dark-mode-uicolor-compatibility/
extension UIColor {
	/// `.systemBackground ?? .white`
	static var sysBg: UIColor { if #available(iOS 13.0, *) { return .systemBackground } else { return .white } }
	/// `.label ?? .black`
	static var sysFg: UIColor { if #available(iOS 13.0, *) { return .label } else { return .black } }
	/// `.link ?? .systemBlue`
	static var sysLink: UIColor { if #available(iOS 13.0, *) { return .link } else { return .systemBlue } }
	
	/// `.label ?? .black`
	static var sysLabel: UIColor { if #available(iOS 13.0, *) { return .label } else { return .black } }
	/// `.secondaryLabel ?? rgba(60, 60, 67, 0.6)`
	static var sysLabel2: UIColor { if #available(iOS 13.0, *) { return .secondaryLabel } else { return .init(red: 60/255.0, green: 60/255.0, blue: 67/255.0, alpha: 0.6) } }
	/// `.tertiaryLabel ?? rgba(60, 60, 67, 0.3)`
	static var sysLabel3: UIColor { if #available(iOS 13.0, *) { return .tertiaryLabel } else { return .init(red: 60/255.0, green: 60/255.0, blue: 67/255.0, alpha: 0.3) } }
}

extension UIEdgeInsets {
	init(all: CGFloat = 0, top: CGFloat? = nil, left: CGFloat? = nil, bottom: CGFloat? = nil, right: CGFloat? = nil) {
		self.init(top: top ?? all, left: left ?? all, bottom: bottom ?? all, right: right ?? all)
	}
}

precedencegroup CompareAssignPrecedence {
	assignment: true
	associativity: left
	higherThan: ComparisonPrecedence
}

infix operator <-? : CompareAssignPrecedence
infix operator <-/ : CompareAssignPrecedence
extension Equatable {
	/// Assign a new value to `lhs` if `newValue` differs from the previous value. Return `false` if they are equal.
	/// - Returns: `true` if `lhs` was overwritten with another value
	static func <-?(lhs: inout Self, newValue: Self) -> Bool {
		if lhs != newValue {
			lhs = newValue
			return true
		}
		return false
	}
	
	/// Assign a new value to `lhs` if `newValue` differs from the previous value.
	/// Return tuple with both values. Or `nil` if they are equal.
	/// - Returns: `nil` if `previousValue == newValue`
	static func <-/(lhs: inout Self, newValue: Self) -> (previousValue: Self, newValue: Self)? {
		let previousValue = lhs
		if previousValue != newValue {
			lhs = newValue
			return (previousValue, newValue)
		}
		return nil
	}
}
