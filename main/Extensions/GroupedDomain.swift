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
