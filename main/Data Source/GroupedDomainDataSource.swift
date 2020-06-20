import UIKit

protocol GroupedDomainDataSourceDelegate: UITableViewController {
	/// Currently only called when a row is moved and the `tableView` is frontmost.
	func groupedDomainDataSource(needsUpdate row: Int)
}

// ##########################
// #
// #    MARK: DataSource
// #
// ##########################

class GroupedDomainDataSource: FilterPipelineDelegate, SyncUpdateDelegate {
	
	let parent: String?
	private let pipeline = FilterPipeline<GroupedDomain>()
	private lazy var search = SearchBarManager(on: delegate!.tableView)
	private var currentOrder: DateFilterOrderBy = .Date
	private var orderAsc = false
	
	/// Will init `sync.allowPullToRefresh()` on `tableView.refreshControl` as well.
	weak var delegate: GroupedDomainDataSourceDelegate? {
		willSet { if #available(iOS 10.0, *), newValue !== delegate {
			sync.allowPullToRefresh(onTVC: newValue, forObserver: self)
		}}}
	
	/// - Note: Will call `tableview.reloadData()`
	init(withParent: String?) {
		parent = withParent
		pipeline.delegate = self
		resetSortingOrder(force: true)
		
		NotifyDNSFilterChanged.observe(call: #selector(didChangeDomainFilter), on: self)
		NotifySortOrderChanged.observe(call: #selector(didChangeSortOrder), on: self)
		
		sync.addObserver(self) // calls syncUpdate(reset:)
	}
	
	/// Callback fired when user changes date filter settings. (`NotifySortOrderChanged` notification)
	@objc private func didChangeSortOrder(_ notification: Notification) {
		resetSortingOrder()
	}
	
	/// Read user defaults and apply new sorting order. Either by setting a new or reversing the current.
	/// - Parameter force: If `true` set new sorting even if the type does not differ.
	private func resetSortingOrder(force: Bool = false) {
		let orderAscChanged = (orderAsc <-? Pref.DateFilter.OrderAsc)
		let orderTypChanged = (currentOrder <-? Pref.DateFilter.OrderBy)
		if orderTypChanged || force {
			switch currentOrder {
			case .Date:
				pipeline.setSorting { [unowned self] in
					self.orderAsc ? $0.lastModified < $1.lastModified : $0.lastModified > $1.lastModified
				}
			case .Name:
				pipeline.setSorting { [unowned self] in
					self.orderAsc ? $0.domain < $1.domain : $0.domain > $1.domain
				}
			case .Count:
				pipeline.setSorting { [unowned self] in
					self.orderAsc ? $0.total < $1.total : $0.total > $1.total
				}
			}
		} else if orderAscChanged {
			pipeline.reverseSorting()
		}
	}
	
	/// Callback fired when user edits list of `blocked` or `ignored` domains in settings. (`NotifyDNSFilterChanged` notification)
	@objc private func didChangeDomainFilter(_ notification: Notification) {
		guard let domain = notification.object as? String else {
			preconditionFailure("Domain independent filter reset not implemented") // `syncUpdate(reset:)` async!
		}
		if let x = pipeline.dataSourceGet(where: { $0.domain == domain }) {
			var obj = x.object
			obj.options = DomainFilter[domain]
			pipeline.update(obj, at: x.index)
		}
	}
	
	
	// MARK: Table View Data Source
	
	@inline(__always) var numberOfRows: Int { get { pipeline.displayObjectCount() } }
	
	@inline(__always) subscript(_ row: Int) -> GroupedDomain { pipeline.displayObject(at: row) }
}


// ################################
// #
// #    MARK: - Partial Update
// #
// ################################

extension GroupedDomainDataSource {
	
	func syncUpdate(_: SyncUpdate, reset rows: SQLiteRowRange) {
		var logs = AppDB?.dnsLogsGrouped(range: rows, parentDomain: parent) ?? []
		for (i, val) in logs.enumerated() {
			logs[i].options = DomainFilter[val.domain]
		}
		DispatchQueue.main.sync {
			pipeline.reset(dataSource: logs)
		}
	}
	
	func syncUpdate(_: SyncUpdate, insert rows: SQLiteRowRange, affects: SyncUpdateEnd) {
		guard let latest = AppDB?.dnsLogsGrouped(range: rows, parentDomain: parent) else {
			assertionFailure("NotifySyncInsert fired with empty range")
			return
		}
		DispatchQueue.main.sync {
			cellAnimationsGroup(if: latest.count > 14)
			for x in latest {
				if let (i, obj) = pipeline.dataSourceGet(where: { $0.domain == x.domain }) {
					pipeline.update(obj + x, at: i)
				} else {
					var y = x
					y.options = DomainFilter[x.domain]
					pipeline.addNew(y)
				}
			}
			cellAnimationsCommit()
		}
	}
	
	func syncUpdate(_ sender: SyncUpdate, remove rows: SQLiteRowRange, affects: SyncUpdateEnd) {
		if affects == .Latest {
			// TODO: alternatively query last modified from db (last entry _before_ range)
			syncUpdate(sender, reset: sender.rows)
			return
		}
		guard let outdated = AppDB?.dnsLogsGrouped(range: rows, parentDomain: parent),
			outdated.count > 0 else {
				return
		}
		DispatchQueue.main.sync {
			cellAnimationsGroup(if: outdated.count > 14)
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
			cellAnimationsCommit()
		}
	}
	
	func syncUpdate(_ sender: SyncUpdate, partialRemove affectedFQDN: String) {
		let affectedParent = affectedFQDN.extractDomain()
		guard parent == nil || parent == affectedParent else {
			return // does not affect current table
		}
		let affected = (parent == nil ? affectedParent : affectedFQDN)
		let updated = AppDB?.dnsLogsGrouped(range: sender.rows, matchingDomain: affected, parentDomain: parent)?.first
		DispatchQueue.main.sync {
			guard let old = pipeline.dataSourceGet(where: { $0.domain == affected }) else {
				// can only happen if delete sheet is open while background sync removed the element
				return
			}
			if var updated = updated {
				assert(old.object.domain == updated.domain)
				updated.options = DomainFilter[updated.domain]
				pipeline.update(updated, at: old.index)
			} else {
				pipeline.remove(indices: [old.index])
			}
		}
	}
}


// #################################
// #
// #    MARK: - Cell Animations
// #
// #################################

extension GroupedDomainDataSource {
	/// Sets `pipeline.delegate = nil` to disable individual cell animations (update, insert, delete & move).
	private func cellAnimationsGroup(if condition: Bool = true) {
		if condition || delegate?.tableView.isFrontmost == false {
			pipeline.delegate = nil
		}
	}
	/// No-Op if cell animations are enabled already.
	/// Else, set `pipeline.delegate = self` and perform `reloadData()`.
	private func cellAnimationsCommit() {
		if pipeline.delegate == nil {
			pipeline.delegate = self
			delegate?.tableView.reloadData()
		}
	}
	
	// TODO: Collect animations and post them in a single animations block.
	//       This will require enormous work to translate them into a final set.
	func filterPipelineDidReset() { delegate?.tableView.reloadData() }
	func filterPipeline(delete rows: [Int]) { delegate?.tableView.safeDeleteRows(rows) }
	func filterPipeline(insert row: Int) { delegate?.tableView.safeInsertRow(row, with: .left) }
	func filterPipeline(update row: Int) {
		guard let tv = delegate?.tableView else { return }
		if !tv.isEditing { tv.safeReloadRow(row) }
		else if tv.isFrontmost == true {
			delegate?.groupedDomainDataSource(needsUpdate: row)
		}
	}
	func filterPipeline(move oldRow: Int, to newRow: Int) {
		delegate?.tableView.safeMoveRow(oldRow, to: newRow)
		if delegate?.tableView.isFrontmost == true {
			delegate?.groupedDomainDataSource(needsUpdate: newRow)
		}
	}
}


// ################################
// #
// #    MARK: - Search
// #
// ################################

extension GroupedDomainDataSource {
	// TODO: permanently show search bar as table header?
	func toggleSearch() {
		if search.active { search.hide() }
		else {
			// Begin animations group. Otherwise the `scrollToTop` animation is broken.
			// This is due to `addFilter` calling `reloadData()` before `search.show()` can animate it.
			cellAnimationsGroup()
			var searchTerm = ""
			let len = parent?.count ?? 0
			pipeline.addFilter("search") {
				$0.domain.prefix($0.domain.count - len).lowercased().contains(searchTerm)
			}
			search.show(onHide: { [unowned self] in
				self.pipeline.removeFilter(withId: "search")
			}, onChange: { [unowned self] in
				searchTerm = $0.lowercased()
				self.pipeline.reloadFilter(withId: "search")
			})
			cellAnimationsCommit()
		}
	}
}


// ##########################
// #
// #    MARK: - Edit Row
// #
// ##########################

protocol GroupedDomainEditRow : UIViewController, EditableRows {
	var source: GroupedDomainDataSource { get }
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
			let name = entry.domain
			let flag = (source.parent != nil)
			AlertDeleteLogs(name, latest: entry.lastModified) {
				TheGreatDestroyer.deleteLogs(domain: name, since: $0, strict: flag)
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
