import UIKit

extension GroupedDomain {
	var detailCellText: String { get {
		return blocked > 0
		? "\(lastModified.asDateTime())   —   \(blocked)/\(total) blocked"
		: "\(lastModified.asDateTime())   —   \(total)"
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

extension NSMutableAttributedString {
	func withColor(_ color: UIColor, fromBack: Int) -> Self {
		let l = length - fromBack
		let r = (l < 0) ? NSMakeRange(0, length) : NSMakeRange(l, fromBack)
		self.addAttribute(.foregroundColor, value: color, range: r)
		return self
	}
}

// MARK: Pull-to-Refresh

extension UIRefreshControl {
	convenience init(call: Selector, on: UITableViewController) {
		self.init()
		addTarget(on, action: call, for: .valueChanged)
		addTarget(self, action: #selector(endRefreshing), for: .valueChanged)
	}
	
}

// MARK: TableView extensions

extension IndexPath {
	/// Convenience init with `section: 0`
	public init(row: Int) { self.init(row: row, section: 0) }
}

extension UITableView {
	/// Returns `true` if this `tableView` is the currently frontmost visible
	var isFrontmost: Bool { window?.isKeyWindow ?? false }
	
	/// If frontmost window, perform `deleteRows()`; If not, perform `reloadData()`
	func safeDeleteRow(_ index: Int, with animation: UITableView.RowAnimation = .automatic) {
		isFrontmost ? deleteRows(at: [IndexPath(row: index)], with: animation) : reloadData()
	}
	/// If frontmost window, perform `reloadRows()`; If not, perform `reloadData()`
	func safeReloadRow(_ index: Int, with animation: UITableView.RowAnimation = .automatic) {
		isFrontmost ? reloadRows(at: [IndexPath(row: index)], with: animation) : reloadData()
	}
	/// If frontmost window, perform `insertRows()`; If not, perform `reloadData()`
	func safeInsertRow(_ index: Int, with animation: UITableView.RowAnimation = .automatic) {
		isFrontmost ? insertRows(at: [IndexPath(row: index)], with: animation) : reloadData()
	}
	/// If frontmost window, perform `moveRow()`; If not, perform `reloadData()`
	func safeMoveRow(_ from: Int, to: Int) {
		isFrontmost ? moveRow(at: IndexPath(row: from), to: IndexPath(row: to)) : reloadData()
	}
}


// MARK: - Incremental Update Delegate

enum IncrementalDataSourceUpdateOperation {
	case ReloadTable, Update, Insert, Delete, Move
}

protocol IncrementalDataSourceUpdate : UITableViewController {
	var dataSource: [GroupedDomain] { get set }
	func shouldLiveUpdateIncrementalDataSource() -> Bool
	/// - Warning: Called on a background thread!
	/// - Parameters:
	///   - operation: Row update action
	///   - row: Which row index is affected? `IndexPath(row: row)`
	///   - moveTo: Only set for `Move` operation, otherwise `-1`
	func didUpdateIncrementalDataSource(_ operation: IncrementalDataSourceUpdateOperation, row: Int, moveTo: Int)
}

extension IncrementalDataSourceUpdate {
	func shouldLiveUpdateIncrementalDataSource() -> Bool { true }
	func didUpdateIncrementalDataSource(_: IncrementalDataSourceUpdateOperation, row: Int, moveTo: Int) {}
	// TODO: custom handling if cell is being edited
	
	func insertRow(_ obj: GroupedDomain, at index: Int) {
		dataSource.insert(obj, at: index)
		if shouldLiveUpdateIncrementalDataSource() {
			DispatchQueue.main.sync { tableView.safeInsertRow(index, with: .left) }
		}
		didUpdateIncrementalDataSource(.Insert, row: index, moveTo: -1)
	}
	func moveRow(_ obj: GroupedDomain, from: Int, to: Int) {
		dataSource.remove(at: from)
		dataSource.insert(obj, at: to)
		if shouldLiveUpdateIncrementalDataSource() {
			DispatchQueue.main.sync {
				if tableView.isFrontmost {
					let source = IndexPath(row: from)
					let cell = tableView.cellForRow(at: source)
					cell?.detailTextLabel?.text = obj.detailCellText
					tableView.moveRow(at: source, to: IndexPath(row: to))
				} else {
					tableView.reloadData()
				}
			}
		}
		didUpdateIncrementalDataSource(.Move, row: from, moveTo: to)
	}
	func replaceRow(_ obj: GroupedDomain, at index: Int) {
		dataSource[index] = obj
		if shouldLiveUpdateIncrementalDataSource() {
			DispatchQueue.main.sync { tableView.safeReloadRow(index) }
		}
		didUpdateIncrementalDataSource(.Update, row: index, moveTo: -1)
	}
	func deleteRow(at index: Int) {
		dataSource.remove(at: index)
		if shouldLiveUpdateIncrementalDataSource() {
			DispatchQueue.main.sync { tableView.safeDeleteRow(index) }
		}
		didUpdateIncrementalDataSource(.Delete, row: index, moveTo: -1)
	}
	func replaceData(with newData: [GroupedDomain]) {
		dataSource = newData
		if shouldLiveUpdateIncrementalDataSource() {
			DispatchQueue.main.sync { tableView.reloadData() }
		}
		didUpdateIncrementalDataSource(.ReloadTable, row: -1, moveTo: -1)
	}
}
