import UIKit

class TVCHostDetails: UITableViewController {

	public var fullDomain: String!
	private var dataSource: [GroupedTsOccurrence] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.prompt = fullDomain
		if #available(iOS 10.0, *) {
			tableView.refreshControl = UIRefreshControl(call: #selector(reloadDataSource), on: self)
		}
		NotifyLogHistoryReset.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
	}
	
	@objc func reloadDataSource() {
		dataSource = DBWrp.listOfTimes(fullDomain)
		tableView.reloadData()
	}
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HostDetailCell")!
		let src = dataSource[indexPath.row]
		cell.textLabel?.text = src.ts.asDateTime()
		cell.detailTextLabel?.text = (src.total > 1) ? "\(src.total)x" : nil
		cell.imageView?.image = (src.blocked > 0 ? UIImage(named: "shield-x") : nil)
		return cell
	}
}
