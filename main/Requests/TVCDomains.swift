import UIKit

class TVCDomains: UITableViewController, IncrementalDataSourceUpdate {
	
	internal var dataSource: [GroupedDomain] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if #available(iOS 10.0, *) {
			tableView.refreshControl = UIRefreshControl(call: #selector(reloadDataSource), on: self)
		}
		NotifyLogHistoryReset.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
		DBWrp.dataA_delegate = self
	}
	
	@objc func reloadDataSource() {
		dataSource = DBWrp.listOfDomains()
		tableView.reloadData()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			(segue.destination as? TVCHosts)?.parentDomain = dataSource[index].domain
		}
	}
	
	
	// MARK: - Table View Delegate
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DomainCell")!
		let entry = dataSource[indexPath.row]
		cell.textLabel?.text = entry.domain
		cell.detailTextLabel?.text = entry.detailCellText
		cell.imageView?.image = entry.options?.tableRowImage()
		return cell
	}
}
