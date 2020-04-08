import UIKit

public enum RowAction {
	case ignore, block, delete
//	static let all: [RowAction] = [.ignore, .block, .delete]
}

// MARK: - Generic

protocol EditableRows {
	func editableRowUserInfo(_ index: IndexPath) -> Any?
	func editableRowActions(_ index: IndexPath) -> [(RowAction, String)]
	func editableRowActionColor(_ index: IndexPath, _ action: RowAction) -> UIColor?
	@discardableResult func editableRowCallback(_ atIndexPath: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool
}

extension EditableRows where Self: UITableViewController {
	fileprivate func getRowActionsIOS9(_ index: IndexPath) -> [UITableViewRowAction]? {
		let userInfo = editableRowUserInfo(index)
		return editableRowActions(index).compactMap { a,t in
			let x = UITableViewRowAction(style: a == .delete ? .destructive : .normal, title: t) { self.editableRowCallback($1, a, userInfo) }
			if let color = editableRowActionColor(index, a) {
				x.backgroundColor = color
			}
			return x
		}
	}
	@available(iOS 11.0, *)
	fileprivate func getRowActionsIOS11(_ index: IndexPath) -> UISwipeActionsConfiguration? {
		let userInfo = editableRowUserInfo(index)
		return UISwipeActionsConfiguration(actions: editableRowActions(index).compactMap { a,t in
			let x = UIContextualAction(style: a == .delete ? .destructive : .normal, title: t) { $2(self.editableRowCallback(index, a, userInfo)) }
			x.backgroundColor = editableRowActionColor(index, a)
			return x
		})
	}
	func editableRowUserInfo(_ index: IndexPath) -> Any? { nil }
}



// MARK: - Edit Ignore-Block-Delete

protocol EditActionsIgnoreBlockDelete : EditableRows {
	var dataSource: [GroupedDomain] { get set }
}
extension EditActionsIgnoreBlockDelete where Self: UITableViewController {
	func editableRowActions(_ index: IndexPath) -> [(RowAction, String)] {
		let x = dataSource[index.row]
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
	
	func editableRowUserInfo(_ index: IndexPath) -> Any? { dataSource[index.row] }
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		let entry = userInfo as! GroupedDomain
		switch action {
		case .ignore: showFilterSheet(entry, .ignored)
		case .block:  showFilterSheet(entry, .blocked)
		case .delete:
			AlertDeleteLogs(entry.domain, latest: entry.lastModified) {
				DBWrp.deleteHistory(domain: entry.domain, since: $0)
			}.presentIn(self)
		}
		return true
	}
	
	private func showFilterSheet(_ entry: GroupedDomain, _ filter: FilterOptions) {
		if entry.options?.contains(filter) ?? false {
			DBWrp.updateFilter(entry.domain, remove: filter)
		} else {
			// TODO: alert sheet
			DBWrp.updateFilter(entry.domain, add: filter)
		}
	}
}

// MARK: Extensions
extension TVCDomains : EditActionsIgnoreBlockDelete {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}

extension TVCHosts : EditActionsIgnoreBlockDelete {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}



// MARK: - Edit Remove

protocol EditActionsRemove : EditableRows {}
extension EditActionsRemove where Self: UITableViewController {
	func editableRowActions(_: IndexPath) -> [(RowAction, String)] { [(.delete, "Remove")] }
	func editableRowActionColor(_: IndexPath, _: RowAction) -> UIColor? { nil }
}

// MARK: Extensions
extension TVCFilter : EditableRows {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}

extension TVCPreviousRecords : EditableRows {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}

extension TVCRecordingDetails : EditableRows {
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
}
