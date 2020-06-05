import UIKit

// ##########################
// #
// #    MARK: DataSource
// #
// ##########################

class GroupedDomainDataSource {
	
	private var tsLatest: Timestamp = 0
	
	private let parent: String?
	let pipeline: FilterPipeline<GroupedDomain>
	private lazy var search = SearchBarManager(on: pipeline.delegate!.tableView)
	
	init(withDelegate tvc: FilterPipelineDelegate, parent p: String?) {
		parent = p
		pipeline = .init(withDelegate: tvc)
		pipeline.setDataSource { [unowned self] in self.dataSourceCallback() }
		pipeline.setSorting {
			$0.lastModified > $1.lastModified
		}
		if #available(iOS 10.0, *) {
			tvc.tableView.refreshControl = UIRefreshControl(call: #selector(reloadFromSource), on: self)
		}
		NotifyLogHistoryReset.observe(call: #selector(reloadFromSource), on: self)
		NotifyDNSFilterChanged.observe(call: #selector(didChangeDomainFilter), on: self)
		NotifySyncInsert.observe(call: #selector(syncInsert), on: self)
		NotifySyncRemove.observe(call: #selector(syncRemove), on: self)
	}
	
	/// Callback fired only when pipeline resets data source
	private func dataSourceCallback() -> [GroupedDomain] {
		guard let db = AppDB else { return [] }
		let earliest = sync.tsEarliest
		tsLatest = earliest
		var log = db.dnsLogsGrouped(since: earliest, parentDomain: parent) ?? []
		for (i, val) in log.enumerated() {
			log[i].options = DomainFilter[val.domain]
			tsLatest = max(tsLatest, val.lastModified)
		}
		return log
	}
	
	/// Pause recurring background updates to force reload `dataSource`.
	/// Callback fired on user action `pull-to-refresh`, or another background task triggered `NotifyLogHistoryReset`.
	/// - Parameter sender: May be either `UIRefreshControl` or `Notification`
	///                     (optional: pass single domain as the notification object).
	@objc func reloadFromSource(sender: Any? = nil) {
		weak var refreshControl = sender as? UIRefreshControl
		let notification = sender as? Notification
		sync.pause()
		if let affectedDomain = notification?.object as? String {
			partiallyReloadFromSource(affectedDomain)
			sync.continue()
		} else {
			pipeline.reload(fromSource: true, whenDone: {
				sync.continue()
				refreshControl?.endRefreshing()
			})
		}
	}
	
	/// Callback fired when user editslist of `blocked` or `ignored` domains in settings. (`NotifyDNSFilterChanged` notification)
	@objc private func didChangeDomainFilter(_ notification: Notification) {
		guard let domain = notification.object as? String else {
			reloadFromSource()
			return
		}
		if let (i, obj) = pipeline.dataSourceGet(where: { $0.domain == domain }) {
			var y = obj
			y.options = DomainFilter[domain]
			pipeline.update(y, at: i)
		}
	}
	
	
	// MARK: Table View Data Source
	
	@inline(__always) var numberOfRows: Int { get { pipeline.displayObjectCount() } }
	
	@inline(__always) subscript(_ row: Int) -> GroupedDomain { pipeline.displayObject(at: row) }
	
	
	// MARK: partial updates
	
	/// Callback fired when background sync added new entries to the list. (`NotifySyncInsert` notification)
	@objc private func syncInsert(_ notification: Notification) {
		sync.pause()
		defer { sync.continue() }
		let range = notification.object as! SQLiteRowRange
		guard let latest = AppDB?.dnsLogsGrouped(range: range, parentDomain: parent) else {
			assertionFailure("NotifySyncInsert fired with empty range")
			return
		}
		pipeline.pauseCellAnimations(if: latest.count > 14)
		for x in latest {
			if let (i, obj) = pipeline.dataSourceGet(where: { $0.domain == x.domain }) {
				pipeline.update(obj + x, at: i)
			} else {
				var y = x
				y.options = DomainFilter[x.domain]
				pipeline.addNew(y)
			}
			tsLatest = max(tsLatest, x.lastModified)
		}
		pipeline.continueCellAnimations(reloadTable: true)
	}
	
	/// Callback fired when background sync removed old entries from the list. (`NotifySyncRemove` notification)
	@objc private func syncRemove(_ notification: Notification) {
		sync.pause()
		defer { sync.continue() }
		let range = notification.object as! SQLiteRowRange
		guard let outdated = AppDB?.dnsLogsGrouped(range: range, parentDomain: parent),
			outdated.count > 0 else {
				return
		}
		pipeline.pauseCellAnimations(if: outdated.count > 14)
		var listOfDeletes: [Int] = []
		for x in outdated {
			guard let (i, obj) = pipeline.dataSourceGet(where: { $0.domain == x.domain }) else {
				assertionFailure("Try to remove non-existent element")
				continue // should never happen
			}
			if obj.total > x.total {
				pipeline.update(obj - x, at: i)
			} else {
				listOfDeletes.append(i)
			}
		}
		pipeline.remove(indices: listOfDeletes.sorted())
		pipeline.continueCellAnimations(reloadTable: true)
	}
}


// ################################
// #
// #    MARK: - Delete History
// #
// ################################

extension GroupedDomainDataSource {
	
	/// Callback fired when user performs row edit -> delete action
	func deleteHistory(domain: String, since ts: Timestamp) {
		let flag = (parent != nil)
		DispatchQueue.global().async {
			guard let db = AppDB, db.dnsLogsDelete(domain, strict: flag, since: ts) > 0 else {
				return // nothing has changed
			}
			db.vacuum()
			NotifyLogHistoryReset.postAsyncMain(domain) // calls partiallyReloadFromSource(:)
		}
	}
	
	/// Reload a single data source entry. Callback fired by `reloadFromSource()`
	/// Only useful if `affectedFQDN` currently exists in `dataSource`. Can either update or remove entry.
	private func partiallyReloadFromSource(_ affectedFQDN: String) {
		let affectedParent = affectedFQDN.extractDomain()
		guard parent == nil || parent == affectedParent else {
			return // does not affect current table
		}
		let affected = (parent == nil ? affectedParent : affectedFQDN)
		guard let old = pipeline.dataSourceGet(where: { $0.domain == affected }) else {
			// can only happen if delete sheet is open while background sync removed the element
			return
		}
		if var updated = AppDB?.dnsLogsGrouped(since: sync.tsEarliest, upto: tsLatest,
											   matchingDomain: affected, parentDomain: parent)?.first {
			assert(old.object.domain == updated.domain)
			updated.options = DomainFilter[updated.domain]
			pipeline.update(updated, at: old.index)
		} else {
			pipeline.remove(indices: [old.index])
		}
	}
}


// ################################
// #
// #    MARK: - Search
// #
// ################################

extension GroupedDomainDataSource {
	func toggleSearch() {
		if search.active { search.hide() }
		else {
			// Pause animations. Otherwise the `scrollToTop` animation is broken.
			// This is due to `addFilter` calling `reloadData()` before `search.show()` can animate it.
			pipeline.pauseCellAnimations()
			var searchTerm = ""
			pipeline.addFilter("search") {
				$0.domain.lowercased().contains(searchTerm)
			}
			search.show(onHide: { [unowned self] in
				self.pipeline.removeFilter(withId: "search")
			}, onChange: { [unowned self] in
				searchTerm = $0.lowercased()
				self.pipeline.reloadFilter(withId: "search")
			})
			pipeline.continueCellAnimations()
		}
	}
}


// ##########################
// #
// #    MARK: - Edit Row
// #
// ##########################

protocol GroupedDomainEditRow : EditableRows, FilterPipelineDelegate {
	var source: GroupedDomainDataSource { get set }
}

extension GroupedDomainEditRow  {
	
	func editableRowActions(_ index: IndexPath) -> [(RowAction, String)] {
		let x = source[index.row]
		if x.domain.starts(with: "#") {
			return [(.delete, "Delete")]
		}
		let b = x.options?.contains(.blocked) ?? false
		let i = x.options?.contains(.ignored) ?? false
		return [(.delete, "Delete"), (.block, b ? "Unblock" : "Block"), (.ignore, i ? "Unignore" : "Ignore")]
	}
	
	func editableRowActionColor(_: IndexPath, _ action: RowAction) -> UIColor? {
		action == .block ? .systemOrange : nil
	}
	
	func editableRowUserInfo(_ index: IndexPath) -> Any? { source[index.row] }
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		let entry = userInfo as! GroupedDomain
		switch action {
		case .ignore: showFilterSheet(entry, .ignored)
		case .block:  showFilterSheet(entry, .blocked)
		case .delete:
			AlertDeleteLogs(entry.domain, latest: entry.lastModified) {
				self.source.deleteHistory(domain: entry.domain, since: $0)
			}.presentIn(self)
		}
		return true
	}
	
	private func showFilterSheet(_ entry: GroupedDomain, _ filter: FilterOptions) {
		if entry.options?.contains(filter) ?? false {
			DomainFilter.update(entry.domain, remove: filter)
		} else {
			// TODO: alert sheet
			DomainFilter.update(entry.domain, add: filter)
		}
	}
}

// MARK: Extensions
extension TVCDomains : GroupedDomainEditRow {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}

extension TVCHosts : GroupedDomainEditRow {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}
