import UIKit

extension GroupedDomain {
	var detailCellText: String { get {
		return blocked > 0
		? "\(dateTimeFormat.string(from: lastModified))   —   \(blocked)/\(total) blocked"
		: "\(dateTimeFormat.string(from: lastModified))   —   \(total)"
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

// MARK: - Incremental Update Delegate

protocol IncrementalDataSourceUpdate : UITableViewController {
	var dataSource: [GroupedDomain] { get set }
}

extension IncrementalDataSourceUpdate {
	func ifDisplayed(_ block: () -> Void) {
		DispatchQueue.main.sync {
			if self.tableView.window?.isKeyWindow ?? false {
				block()
				// TODO: custom handling if cell is being edited
			} else {
				self.tableView.reloadData()
			}
		}
	}
	func insertRow(_ obj: GroupedDomain, at index: Int) {
		dataSource.insert(obj, at: index)
		ifDisplayed {
			self.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .left)
		}
	}
	func moveRow(_ obj: GroupedDomain, from: Int, to: Int) {
		dataSource.remove(at: from)
		dataSource.insert(obj, at: to)
		ifDisplayed {
			let source = IndexPath(row: from, section: 0)
			let cell = self.tableView.cellForRow(at: source)
			cell?.detailTextLabel?.text = obj.detailCellText
			self.tableView.moveRow(at: source, to: IndexPath(row: to, section: 0))
		}
	}
	func replaceRow(_ obj: GroupedDomain, at index: Int) {
		dataSource[index] = obj
		ifDisplayed {
			self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
		}
	}
	func deleteRow(at index: Int) {
		dataSource.remove(at: index)
		ifDisplayed {
			self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
		}
	}
	func replaceData(with newData: [GroupedDomain]) {
		dataSource = newData
		ifDisplayed {
			self.tableView.reloadData()
		}
	}
}
