import Foundation

class SyncUpdate {
	private var timer: Timer!
	private var paused: Int = 1 // first start() will decrement
	private(set) var tsEarliest: Timestamp
	
	init(periodic interval: TimeInterval) {
		tsEarliest = Pref.DateFilter.lastXMinTimestamp() ?? 0
		NotifyDateFilterChanged.observe(call: #selector(didChangeDateFilter), on: self)
		timer = Timer.repeating(interval, call: #selector(periodicUpdate), on: self)
	}
	
	@objc private func didChangeDateFilter() {
		let lastXFilter = Pref.DateFilter.lastXMinTimestamp() ?? 0
		if tsEarliest < lastXFilter {
			if let excess = AppDB?.dnsLogsRowRange(between: tsEarliest, and: lastXFilter) {
				NotifySyncRemove.post(excess)
			}
		} else if tsEarliest > lastXFilter {
			if let missing = AppDB?.dnsLogsRowRange(between: lastXFilter, and: tsEarliest) {
				NotifySyncInsert.post(missing)
			}
		}
		tsEarliest = lastXFilter
	}
	
	func pause() { paused += 1 }
	func start() { if paused > 0 { paused -= 1 } }
	
	@objc private func periodicUpdate() {
		guard paused == 0, let db = AppDB else { return }
		if let inserted = db.dnsLogsPersist() { // move cache -> heap
			NotifySyncInsert.post(inserted)
		}
		if let lastXFilter = Pref.DateFilter.lastXMinTimestamp(), tsEarliest < lastXFilter {
			if let removed = db.dnsLogsRowRange(between: tsEarliest, and: lastXFilter) {
				NotifySyncRemove.post(removed)
			}
			tsEarliest = lastXFilter
		}
		// TODO: periodic hard delete old logs (will reset rowids!)
	}
}
