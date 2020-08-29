import UIKit

extension GroupedDomain {
	/// Return new `GroupedDomain` by adding `total` and `blocked` counts. Set `lastModified` to the maximum of the two.
	static func +(a: GroupedDomain, b: GroupedDomain) -> Self {
		GroupedDomain(domain: a.domain, total: a.total + b.total, blocked: a.blocked + b.blocked,
					  lastModified: max(a.lastModified, b.lastModified), options: a.options ?? b.options )
	}
	/// Return new `GroupedDomain` by subtracting `total` and `blocked` counts.
	static func -(a: GroupedDomain, b: GroupedDomain) -> Self {
		GroupedDomain(domain: a.domain, total: a.total - b.total, blocked: a.blocked - b.blocked,
					  lastModified: a.lastModified, options: a.options )
	}
}

extension GroupedDomain {
	var detailCellText: String { get {
		return blocked > 0
		? "\(DateFormat.seconds(lastModified))   —   \(blocked)/\(total) blocked"
		: "\(DateFormat.seconds(lastModified))   —   \(total)"
		}
	}
}

extension FilterOptions {
	func tableRowImage() -> UIImage? {
		let blocked = contains(.blocked)
		let ignored = contains(.ignored)
		if blocked { return UIImage(named: ignored ? "block_ignore" : "shield-x") }
		if ignored { return UIImage(named: "quicklook-not") }
		return nil
	}
}

extension Recording {
	var fallbackTitle: String { get {
		isLongTerm ? "Background Recording" : "Unnamed Recording #\(id)"
	} }
	var duration: Timestamp? { get { stop == nil ? nil : stop! - start } }
	var isLongTerm: Bool { (duration ?? 0) > Timestamp.hours(1) }
	var isShared: Bool { uploadkey?.count ?? 0 > 0}
}

