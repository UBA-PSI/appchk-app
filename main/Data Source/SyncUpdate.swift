import Foundation

class SyncUpdate {
	private var lastSync: TimeInterval = 0
	private var timer: Timer!
	private var paused: Int = 1 // first start() will decrement
	private(set) var tsEarliest: Timestamp
	
	init(periodic interval: TimeInterval) {
		tsEarliest = Pref.DateFilter.lastXMinTimestamp() ?? 0
		NotifyDateFilterChanged.observe(call: #selector(didChangeDateFilter), on: self)
		timer = Timer.repeating(interval, call: #selector(periodicUpdate), on: self)
		syncNow() // because timer will only fire after interval
	}
	
	@objc private func periodicUpdate() { if paused == 0 { syncNow() } }
	
	@objc private func didChangeDateFilter() {
		DispatchQueue.global().async {
			self.set(newEarliest: Pref.DateFilter.lastXMinTimestamp() ?? 0)
		}
	}
	
	/// This will immediately resume timer updates, ignoring previous `pause()` requests.
	func start() { paused = 0 }
	
	/// All calls must be balanced with `continue()` calls.
	/// Can be nested within other `pause-continue` pairs.
	/// - Warning: An execution branch that results in unbalanced pairs will completely disable updates!
	func pause() { paused += 1 }
	
	/// Must be balanced with a `pause()` call. A `continue()` without a `pause()` is a `nop`.
	/// - Note: Internally the sync timer keeps running. The `pause` will simply ignore execution during that time.
	func `continue`() { if paused > 0 { paused -= 1 } }
	
	/// Persist logs from cache and notify all observers. (`NotifySyncInsert`)
	/// Determine rows of outdated entries that should be removed and notify observers as well. (`NotifySyncRemove`)
	/// - Note: This method is rate limited. Sync will be performed at most once per second.
	/// - Note: This method returns immediatelly. Syncing is done in a background thread.
	func syncNow() {
		let now = Date().timeIntervalSince1970
		guard (now - lastSync) > 1 else { return } // rate limiting
		lastSync = now
		
		DispatchQueue.global().async {
			self.pause() // reduce concurrent load
			
			if let inserted = AppDB?.dnsLogsPersist() { // move cache -> heap
				NotifySyncInsert.postAsyncMain(inserted)
			}
			if let lastXFilter = Pref.DateFilter.lastXMinTimestamp() {
				self.set(newEarliest: lastXFilter)
			}
			// TODO: periodic hard delete old logs (will reset rowids!)
			
			self.continue()
		}
	}
	
	/// - Warning: Always call from a background thread!
	private func set(newEarliest: Timestamp) {
		let current = tsEarliest
		tsEarliest = newEarliest
		if current < newEarliest {
			if let excess = AppDB?.dnsLogsRowRange(between: current, and: newEarliest) {
				NotifySyncRemove.postAsyncMain(excess)
			}
		} else if current > newEarliest {
			if let missing = AppDB?.dnsLogsRowRange(between: newEarliest, and: current) {
				NotifySyncInsert.postAsyncMain(missing)
			}
		} // else: nothing changed
	}
}
