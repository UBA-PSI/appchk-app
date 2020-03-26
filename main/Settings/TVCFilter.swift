import UIKit

class TVCFilter: UITableViewController, EditActionsRemove {
	var currentFilter: FilterOptions = .none
	private var dataSource: [String] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if #available(iOS 10.0, *) {
			tableView.refreshControl = UIRefreshControl(call: #selector(reloadDataSource), on: self)
		}
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
		alert.addTextField { $0.placeholder = "cdn.domain.tld" }
		alert.presentIn(self)
	}
	
	// MARK: - Table View Delegate
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DomainFilterCell")!
		cell.textLabel?.text = dataSource[indexPath.row]
		return cell
	}
	
	// MARK: - Editing
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		let domain = self.dataSource[index.row]
		DBWrp.updateFilter(domain, remove: currentFilter)
		self.dataSource.remove(at: index.row)
		self.tableView.deleteRows(at: [index], with: .automatic)
		return true
	}
}
