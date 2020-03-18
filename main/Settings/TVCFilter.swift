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
