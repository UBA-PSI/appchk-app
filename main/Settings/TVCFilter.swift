import UIKit

class TVCFilter: UITableViewController, EditActionsRemove {
	var currentFilter: FilterOptions = .none
	private var dataSource: [String] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
//		if #available(iOS 10.0, *) {
//			tableView.refreshControl = UIRefreshControl(call: #selector(reloadDataSource), on: self)
//		}
		NotifyFilterChanged.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
	}

	@objc func reloadDataSource() {
		dataSource = DBWrp.dataF_list(currentFilter)
		tableView.reloadData()
	}
	
	@IBAction private func addNewFilter() {
		let desc: String
		switch currentFilter {
		case .blocked: desc = "Enter the domain name you wish to block."
		case .ignored: desc = "Enter the domain name you wish to ignore."
		default: return
		}
		let alert = AskAlert(title: "Create new filter", text: desc, buttonText: "Add") {
			guard let dom = $0.textFields?.first?.text else {
				return
			}
			guard dom.contains("."), !dom.isKnownSLD() else {
				ErrorAlert("Entered domain is not valid. Filter can't match country TLD only.").presentIn(self)
				return
			}
			DBWrp.updateFilter(dom, add: self.currentFilter)
		}
		alert.addTextField {
			$0.placeholder = "cdn.domain.tld"
			$0.keyboardType = .URL
		}
		alert.presentIn(self)
	}
	
	// MARK: - Table View Delegate
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DomainFilterCell")!
		cell.textLabel?.text = dataSource[indexPath.row]
		if cell.gestureRecognizers?.isEmpty ?? true {
			cell.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongTap)))
		}
		return cell
	}
	
	// MARK: - Editing
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		let domain = dataSource[index.row]
		DBWrp.updateFilter(domain, remove: currentFilter)
		dataSource.remove(at: index.row)
		tableView.deleteRows(at: [index], with: .automatic)
		return true
	}
	
	// MARK: - Long Press Gesture
	
	private var cellTitleCopy: String?
	
	@objc private func didLongTap(_ sender: UILongPressGestureRecognizer) {
		guard let cell = sender.view as? UITableViewCell else {
			return
		}
		if sender.state == .began {
			cellTitleCopy = cell.textLabel?.text
			self.becomeFirstResponder()
			let menu = UIMenuController.shared
//			menu.setTargetRect(CGRect(origin: sender.location(in: cell), size: CGSize.zero), in: cell)
			menu.setTargetRect(cell.bounds, in: cell)
			menu.setMenuVisible(true, animated: true)
		}
    }
	override var canBecomeFirstResponder: Bool { get { true } }
	
	override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
		action == #selector(UIResponderStandardEditActions.copy)
	}
	
	override func copy(_ sender: Any?) {
		UIPasteboard.general.string = cellTitleCopy
		cellTitleCopy = nil
	}
}
