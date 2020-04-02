import Foundation

extension GroupedDomain {
	static func +(a: GroupedDomain, b: GroupedDomain) -> Self {
		GroupedDomain(domain: a.domain, total: a.total + b.total, blocked: a.blocked + b.blocked,
					  lastModified: max(a.lastModified, b.lastModified), options: a.options ?? b.options )
	}
}

extension Array where Element == GroupedDomain {
	func merge(_ domain: String, options opt: FilterOptions? = nil) -> GroupedDomain {
		var b: Int32 = 0, t: Int32 = 0, m: Timestamp = 0
		for x in self {
			b += x.blocked
			t += x.total
			m = Swift.max(m, x.lastModified)
		}
		return GroupedDomain(domain: domain, total: t, blocked: b, lastModified: m, options: opt)
	}
}

extension Recording {
	func stoppedCopy() -> Recording {
		stop != nil ? self : Recording(start: start, stop: Timestamp(Date().timeIntervalSince1970),
									   appId: appId, title: title, notes: notes)
	}
	var fallbackTitle: String { get { "Unnamed #\(start)" } }
	var duration: Timestamp? { get { stop == nil ? nil : stop! - start } }
	var durationString: String? { get { stop == nil ? nil : TimeFormat.from(duration!) } }
}

extension Timestamp {
	func asDateTime() -> String { dateTimeFormat.string(from: self) }
	func toDate() -> Date { Date(timeIntervalSince1970: Double(self)) }
	static func now() -> Timestamp { Timestamp(Date().timeIntervalSince1970) }
}
