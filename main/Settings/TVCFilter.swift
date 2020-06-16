import UIKit

class TVCFilter: UITableViewController, EditActionsRemove {
	var currentFilter: FilterOptions = .none // set by segue
	private lazy var dataSource = DomainFilter.list(where: currentFilter)
	
	override func viewDidLoad() {
		super.viewDidLoad()
		NotifyDNSFilterChanged.observe(call: #selector(didChangeDomainFilter), on: self)
	}
	
	@objc func didChangeDomainFilter(_ notification: Notification) {
		guard let domain = notification.object as? String else {
			preconditionFailure("Domain independent filter reset not implemented")
		}
		if DomainFilter[domain]?.contains(currentFilter) ?? false {
			let i = dataSource.binTreeIndex(of: domain, compare: (<))!
			if i >= dataSource.count || dataSource[i] != domain {
				dataSource.insert(domain, at: i)
				tableView.safeInsertRow(i)
			}
		} else if let i = dataSource.binTreeRemove(domain, compare: (<)) {
			tableView.safeDeleteRows([i])
		}
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
			DomainFilter.update(dom, add: self.currentFilter)
		}
		alert.addTextField {
			$0.placeholder = "cdn.domain.tld"
			$0.keyboardType = .URL
		}
		alert.presentIn(self)
	}
	
	// MARK: - Table View Data Source
	
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
	
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		let domain = dataSource[index.row]
		DomainFilter.update(domain, remove: currentFilter)
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
