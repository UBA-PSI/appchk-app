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
	
	@objc private func periodicUpdate() { if paused == 0 { syncNow() } }
	
	@objc private func didChangeDateFilter() {
		let lastXFilter = Pref.DateFilter.lastXMinTimestamp() ?? 0
		let before = tsEarliest
		tsEarliest = lastXFilter
		if before < lastXFilter {
			DispatchQueue.global().async {
				if let excess = AppDB?.dnsLogsRowRange(between: before, and: lastXFilter) {
					NotifySyncRemove.postAsyncMain(excess)
				}
			}
		} else if before > lastXFilter {
			DispatchQueue.global().async {
				if let missing = AppDB?.dnsLogsRowRange(between: lastXFilter, and: before) {
					NotifySyncInsert.postAsyncMain(missing)
				}
			}
		}
	}
	
	func start() { paused = 0 }
	func pause() { paused += 1 }
	func `continue`() { if paused > 0 { paused -= 1 } }
	
	func syncNow() {
		self.pause() // reduce concurrent load
		
		if let inserted = AppDB?.dnsLogsPersist() { // move cache -> heap
			NotifySyncInsert.post(inserted)
		}
		if let lastXFilter = Pref.DateFilter.lastXMinTimestamp(), tsEarliest < lastXFilter {
			if let removed = AppDB?.dnsLogsRowRange(between: tsEarliest, and: lastXFilter) {
				NotifySyncRemove.post(removed)
			}
			tsEarliest = lastXFilter
		}
		// TODO: periodic hard delete old logs (will reset rowids!)
		
		self.continue()
	}
}
