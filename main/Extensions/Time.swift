import Foundation

extension DateFormatter {
	convenience init(withFormat: String) {
		self.init()
		dateFormat = withFormat
	}
}

extension Date {
	/// Convert `Timestamp` to `Date`
	init(_ ts: Timestamp) { self.init(timeIntervalSince1970: Double(ts)) }
	/// Convert  `Date` to `Timestamp`
	var timestamp: Timestamp { get { Timestamp(self.timeIntervalSince1970) } }
}

extension Timestamp {
	/// Current time as `Timestamp` (second accuracy)
	static func now() -> Timestamp { Date().timestamp }
	/// Create `Timestamp` with `now() - minutes * 60`
	static func past(minutes: Int) -> Timestamp { now() - Timestamp(minutes * 60) }
	/// Create `Timestamp` with `m * 60` seconds
	static func minutes(_ m: Int) -> Timestamp { Timestamp(m * 60) }
	/// Create `Timestamp` with `h * 3600` seconds
	static func hours(_ h: Int) -> Timestamp { Timestamp(h * 3600) }
	/// Create `Timestamp` with `d * 86400` seconds
	static func days(_ d: Int) -> Timestamp { Timestamp(d * 86400) }
}

extension Timer {
	/// Recurring timer maintains a strong reference to `target`.
	@discardableResult static func repeating(_ interval: TimeInterval, call selector: Selector, on target: Any, userInfo: Any? = nil) -> Timer {
		Timer.scheduledTimer(timeInterval: interval, target: target, selector: selector,
							 userInfo: userInfo, repeats: true)
	}
}


// MARK: - DateFormat

enum DateFormat {
	private static let _hms = DateFormatter(withFormat: "yyyy-MM-dd  HH:mm:ss")
	private static let _hm = DateFormatter(withFormat: "yyyy-MM-dd HH:mm")
	
	/// Format: `yyyy-MM-dd  HH:mm:ss`
	static func seconds(_ date: Date) -> String { _hms.string(from: date) }
	/// Format: `yyyy-MM-dd  HH:mm:ss`
	static func seconds(_ ts: Timestamp) -> String { _hms.string(from: Date(ts)) }
	/// Format: `yyyy-MM-dd HH:mm`
	static func minutes(_ date: Date) -> String { _hm.string(from: date) }
	/// Format: `yyyy-MM-dd HH:mm`
	static func minutes(_ ts: Timestamp) -> String { _hm.string(from: Date(ts)) }
}


// MARK: - TimeFormat

struct TimeFormat {
	private var formatter: DateComponentsFormatter
	
	/// Init new formatter with exactly 1 unit count. E.g., `61 min -> 1 hr`
	/// - Parameter allowed: Default: `[.day, .hour, .minute, .second]`
	init(_ style: DateComponentsFormatter.UnitsStyle, allowed: NSCalendar.Unit = [.day, .hour, .minute, .second]) {
		formatter = DateComponentsFormatter()
		formatter.maximumUnitCount = 1
		formatter.allowedUnits = allowed
		formatter.unitsStyle = style
	}
	
	/// Formatted duration string, e.g., `20 min` or `7 days`
	func from(days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> String? {
		formatter.string(from: DateComponents(day: days, hour: hours, minute: minutes, second: seconds))
	}
	
	// MARK: static
	
	/// Time string with format `[HH:]mm:ss` (hours prepended only if duration is 1h+)
	static func from(_ duration: Timestamp) -> String {
		let min = duration / 60
		let sec = duration % 60
		if min >= 60 {
			return String(format: "%02d:%02d:%02d", min / 60, min % 60, sec)
		} else {
			return String(format: "%02d:%02d", min, sec)
		}
	}
	
	/// Duration string with format `mm:ss` or `mm:ss.SSS`
	static func from(_ duration: TimeInterval, millis: Bool = false, hours: Bool = false) -> String {
		var t = Int(duration)
		var min = t / 60
		var sec = t % 60
		if millis {
			let mil = Int(duration * 1000) % 1000
			return String(format: "%02d:%02d.%03d", min, sec, mil)
		} else if hours {
			if t < Recording.minTimeLongTerm {
				t = Int(Recording.minTimeLongTerm) - t
				min = t / 60
				sec = t % 60
				return String(format: "-%02d:%02d:%02d", min / 60, min % 60, sec)
			} else {
				return String(format: "%02d:%02d:%02d", min / 60, min % 60, sec)
			}
		}
		return String(format: "%02d:%02d", min, sec)
	}
	
	/// Duration string with format `mm:ss` or `mm:ss.SSS` or `HH:mm:ss` since reference date
	static func since(_ date: Date, millis: Bool = false, hours: Bool = false) -> String {
		from(Date().timeIntervalSince(date), millis: millis, hours: hours)
	}
}
