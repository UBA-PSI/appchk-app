import UIKit

class SyncUpdate {
	private var lastSync: TimeInterval = 0
	private var timer: Timer!
	private var paused: Int = 1 // first start() will decrement
	
	private var filterType: DateFilterKind
	private var range: SQLiteRowRange? // written in reloadRangeFromDB()
	/// `tsEarliest ?? 0`
	private var tsMin: Timestamp { tsEarliest ?? 0 }
	/// `(tsLatest + 1) ?? 0`
	private var tsMax: Timestamp { (tsLatest ?? -1) + 1 }
	
	/// Returns invalid range `(-1,-1)` if collection contains no rows
	var rows: SQLiteRowRange { get { range ?? (-1,-1) } }
	private(set) var tsEarliest: Timestamp? // as set per user, not actual earliest
	private(set) var tsLatest: Timestamp? // as set per user, not actual latest
	
	
	init(periodic interval: TimeInterval) {
		(filterType, tsEarliest, tsLatest) = Pref.DateFilter.restrictions()
		reloadRangeFromDB()
		
		NotifyDateFilterChanged.observe(call: #selector(didChangeDateFilter), on: self)
		timer = Timer.repeating(interval, call: #selector(periodicUpdate), on: self)
		syncNow() // because timer will only fire after interval
	}
	
	/// Callback fired every `7` seconds.
	@objc private func periodicUpdate() { if paused == 0 { syncNow() } }
	
	/// Callback fired when user changes `DateFilter` on root tableView controller
	@objc private func didChangeDateFilter() {
		self.pause()
		let filter = Pref.DateFilter.restrictions()
		filterType = filter.type
		DispatchQueue.global().async {
			// Not necessary, but improve execution order (delete then insert).
			if self.tsMin <= (filter.earliest ?? 0) {
				self.set(newEarliest: filter.earliest)
				self.set(newLatest: filter.latest)
			} else {
				self.set(newLatest: filter.latest)
				self.set(newEarliest: filter.earliest)
			}
			self.continue()
		}
	}
	
	/// - Warning: Always call from a background thread!
	func needsReloadDB(domain: String? = nil) {
		assert(!Thread.isMainThread)
		reloadRangeFromDB()
		if let dom = domain {
			notifyObservers { $0.syncUpdate(self, partialRemove: dom) }
		} else {
			notifyObservers { $0.syncUpdate(self, reset: rows) }
		}
	}
	
	
	// MARK: - Sync Now
	
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
	/// - Parameter block: **Always** called on a background thread!
	func syncNow(whenDone block: (() -> Void)? = nil) {
		let now = Date().timeIntervalSince1970
		guard (now - lastSync) > 1 else { // rate limiting
			if let b = block { DispatchQueue.global().async { b() } }
			return
		}
		lastSync = now
		self.pause() // reduce concurrent load
		DispatchQueue.global().async {
			self.internalSync()
			block?()
			self.continue()
		}
	}
	
	/// Called by `syncNow()`. Split to a separate func to reduce `self.` cluttering
	private func internalSync() {
		assert(!Thread.isMainThread)
		// Always persist logs ...
		if let newest = AppDB?.dnsLogsPersist() { // move cache -> heap
			if filterType == .ABRange {
				// ... even if we filter a few later
				if let r = rows(tsMin, tsMax, scope: newest) {
					notify(insert: r, front: false)
				}
			} else {
				notify(insert: newest, front: false)
			}
		}
		if filterType == .LastXMin {
			set(newEarliest: Timestamp.past(minutes: Pref.DateFilter.LastXMin))
		}
		// TODO: periodic hard delete old logs (will reset rowids!)
	}
	
	
	// MARK: - Internal
	
	private func reloadRangeFromDB() {
		// `nil` is not SQLiteRowRange(0,0) aka. full collection.
		// `nil` means invalid range. e.g. ts restriction too high or empty db.
		range = rows(tsMin, tsMax)
	}
	
	/// Helper to always set range in case there was none before. Otherwise only update `start`.
	private func safeSetRange(start r: SQLiteRowRange) {
		range == nil ? (range = r) : (range!.start = r.start)
	}
	
	/// Helper to always set range in case there was none before. Otherwise only update `end`.
	private func safeSetRange(end r: SQLiteRowRange) {
		range == nil ? (range = r) : (range!.end = r.end)
	}
	
	/// Update internal `tsEarliest`, then post `NotifySyncInsert` or `NotifySyncRemove` notification with row ids.
	/// - Warning: Always call from a background thread!
	private func set(newEarliest: Timestamp?) {
		func from(_ t: Timestamp?) -> Timestamp { t ?? 0 }
		func to(_ t: Timestamp) -> Timestamp { tsLatest == nil ? t : min(t, tsMax) }
		
		if let (old, new) = tsEarliest <-/ newEarliest {
			if old != nil, (new == nil || new! < old!) {
				if let r = rows(from(new), to(old!), scope: (0, range?.start ?? 0)) {
					notify(insert: r, front: true)
				}
			} else if range != nil {
				if let r = rows(from(old), to(new!), scope: range!) {
					notify(remove: r, front: true)
				}
			}
		}
	}
	
	/// Update internal `tsLatest`, then post `NotifySyncInsert` or `NotifySyncRemove` notification with row ids.
	/// - Warning: Always call from a background thread!
	private func set(newLatest: Timestamp?) {
		func from(_ t: Timestamp) -> Timestamp { max(t + 1, tsMin) }
		func to(_ t: Timestamp?) -> Timestamp { t == nil ? 0 : t! + 1 }
		// +1: include upper end because `dnsLogsRowRange` selects `ts < X`
		
		if let (old, new) = tsLatest <-/ newLatest {
			if old != nil, (new == nil || old! < new!) {
				if let r = rows(from(old!), to(new), scope: (range?.end ?? 0, 0)) {
					notify(insert: r, front: false)
				}
			} else if range != nil {
				// FIXME: removing latest entries will invalidate "last changed" label
				if let r = rows(from(new!), to(old), scope: range!) {
					notify(remove: r, front: false)
				}
			}
		}
	}
	
	private func rows(_ ts1: Timestamp, _ ts2: Timestamp, scope: SQLiteRowRange = (0,0)) -> SQLiteRowRange? {
		AppDB?.dnsLogsRowRange(between: ts1, and: ts2, within: scope)
	}
	
	/// - Warning: Always call from a background thread!
	private func notify(insert r: SQLiteRowRange, front: Bool) {
		front ? safeSetRange(start: r) : safeSetRange(end: r)
		notifyObservers { $0.syncUpdate(self, insert: r) }
	}
	
	/// - Warning: `range` must not be `nil`!
	/// - Warning: Always call from a background thread!
	private func notify(remove r: SQLiteRowRange, front: Bool) {
		front ? (range!.start = r.end + 1) : (range!.end = r.start - 1)
		if range!.start > range!.end { range = nil }
		notifyObservers { $0.syncUpdate(self, remove: r) }
	}
	
	
	// MARK: - Observer List
	
	private var observers: [WeakObserver] = []
	
	/// Add `delegate` to observer list and immediatelly call `syncUpdate(reset:)` (on background thread).
	func addObserver(_ delegate: SyncUpdateDelegate) {
		observers.removeAll { $0.target == nil }
		observers.append(.init(target: delegate))
		DispatchQueue.global().async {
			delegate.syncUpdate(self, reset: self.rows)
		}
	}
	
	/// - Warning: Always call from a background thread!
	private func notifyObservers(_ block: (SyncUpdateDelegate) -> Void) {
		assert(!Thread.isMainThread)
		self.pause()
		for o in observers where o.target != nil { block(o.target!) }
		self.continue()
	}
}

/// Wrapper class for `SyncUpdateDelegate` that supports weak references
private struct WeakObserver {
	weak var target: SyncUpdateDelegate?
	weak var pullToRefresh: UIRefreshControl?
}

protocol SyncUpdateDelegate : AnyObject {
	/// `SyncUpdate` has unpredictable changes. Reload your `dataSource`.
	/// - Warning: This function will **always** be called from a background thread.
	func syncUpdate(_ sender: SyncUpdate, reset rows: SQLiteRowRange)
	
	/// `SyncUpdate` added new `rows` to database. Sync changes to your `dataSource`.
	/// - Warning: This function will **always** be called from a background thread.
	func syncUpdate(_ sender: SyncUpdate, insert rows: SQLiteRowRange)
	
	/// `SyncUpdate` outdated some `rows` in database. Sync changes to your `dataSource`.
	/// - Warning: This function will **always** be called from a background thread.
	func syncUpdate(_ sender: SyncUpdate, remove rows: SQLiteRowRange)
	
	/// Background process did delete some entries in database that match `affectedDomain`.
	/// Update or remove entries from your `dataSource`.
	/// - Warning: This function will **always** be called from a background thread.
	func syncUpdate(_ sender: SyncUpdate, partialRemove affectedDomain: String)
}


// MARK: - Pull-To-Refresh

@available(iOS 10.0, *)
extension SyncUpdate {
	
	/// Add Pull-To-Refresh control to `tableViewController`. On action notify `observer.syncUpdate(reset:)`
	/// - Warning: Must be called after `addObserver()` such that `observer` exists in list of observers.
	func allowPullToRefresh(onTVC tableViewController: UITableViewController?, forObserver: SyncUpdateDelegate) {
		guard let i = observers.firstIndex(where: { $0.target === forObserver }) else {
			assertionFailure("You must add the observer before enabling Pull-To-Refresh!")
			return
		}
		// remove previous
		observers[i].pullToRefresh?.removeTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
		observers[i].pullToRefresh = nil
		if let tvc = tableViewController {
			let rc = UIRefreshControl()
			rc.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
			tvc.tableView.refreshControl = rc
			observers[i].pullToRefresh = rc
		}
	}
	
	/// Pull-To-Refresh callback method. Find observer with corresponding `RefreshControl` and notify `syncUpdate(reset:)`
	@objc private func pullToRefresh(sender: UIRefreshControl) {
		guard let x = observers.first(where: { $0.pullToRefresh === sender }) else {
			assertionFailure("Should never happen. RefreshControl removed from table view while keeping it active somewhere else.")
			return
		}
		syncNow {
			x.target?.syncUpdate(self, reset: self.rows)
			DispatchQueue.main.sync {
				sender.endRefreshing()
			}
		}
	}
}
