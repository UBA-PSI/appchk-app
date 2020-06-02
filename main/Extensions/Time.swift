import Foundation

private let dateTimeFormat = DateFormatter(withFormat: "yyyy-MM-dd  HH:mm:ss")

extension DateFormatter {
	convenience init(withFormat: String) {
		self.init()
		dateFormat = withFormat
	}
}

extension Timestamp {
	/// Time string with format `yyyy-MM-dd  HH:mm:ss`
	func asDateTime() -> String {
		dateTimeFormat.string(from: Date.init(timeIntervalSince1970: Double(self)))
	}
	
	/// Convert `Timestamp` to `Date`
	func toDate() -> Date {
		Date(timeIntervalSince1970: Double(self))
	}
	
	/// Current time as `Timestamp` (second accuracy)
	static func now() -> Timestamp {
		Timestamp(Date().timeIntervalSince1970)
	}
	
	/// Create `Timestamp` with `now() - minutes * 60`
	static func past(minutes: Int) -> Timestamp {
		now() - Timestamp(minutes * 60)
	}
}

extension Timer {
	/// Recurring timer maintains a strong reference to `target`.
	@discardableResult static func repeating(_ interval: TimeInterval, call selector: Selector, on target: Any, userInfo: Any? = nil) -> Timer {
		Timer.scheduledTimer(timeInterval: interval, target: target, selector: selector,
							 userInfo: userInfo, repeats: true)
	}
}

struct TimeFormat {
	/// Time string with format `HH:mm`
	static func from(_ duration: Timestamp) -> String {
		String(format: "%02d:%02d", duration / 60, duration % 60)
	}
	
	/// Duration string with format `HH:mm` or `HH:mm.sss`
	static func from(_ duration: TimeInterval, millis: Bool = false) -> String {
		let t = Int(duration)
		if millis {
			let mil = Int(duration * 1000) % 1000
			return String(format: "%02d:%02d.%03d", t / 60, t % 60, mil)
		}
		return String(format: "%02d:%02d", t / 60, t % 60)
	}
	
	/// Duration string with format `HH:mm` or `HH:mm.sss` since reference date
	static func since(_ date: Date, millis: Bool = false) -> String {
		from(Date().timeIntervalSince(date), millis: millis)
	}
	
	/// Formatted duration string, e.g., `20 min` or `7 days`
	/// - Parameters:
	///   - minutes: Duration in minutes
	///   - style: Default: `.short`
	static func short(minutes: Int, style: DateComponentsFormatter.UnitsStyle = .short) -> String? {
		let dcf = DateComponentsFormatter()
		dcf.maximumUnitCount = 1
		dcf.allowedUnits = [.day, .hour, .minute]
		dcf.unitsStyle = style
		return dcf.string(from: DateComponents(minute: minutes))
	}
}
