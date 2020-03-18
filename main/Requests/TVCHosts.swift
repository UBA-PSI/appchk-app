import UIKit

class TVCHosts: UITableViewController, IncrementalDataSourceUpdate {
	
	public var parentDomain: String!
	internal var dataSource: [GroupedDomain] = []
	private var isSpecial: Bool = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.prompt = parentDomain
		isSpecial = (parentDomain.first == "#") // aka: "# IP address"
		if #available(iOS 10.0, *) {
			tableView.refreshControl = UIRefreshControl(call: #selector(reloadDataSource), on: self)
		}
		NotifyLogHistoryReset.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
		DBWrp.currentlyOpenParent = parentDomain
		DBWrp.dataB_delegate = self
	}
	deinit {
		DBWrp.currentlyOpenParent = nil
	}
	
	@objc func reloadDataSource() {
		dataSource = DBWrp.listOfHosts(parentDomain)
		tableView.reloadData()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			(segue.destination as? TVCHostDetails)?.fullDomain = dataSource[index].domain
		}
	}
	
	// MARK: - Data Source
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HostCell")!
		let entry = dataSource[indexPath.row]
		if isSpecial {
			// currently only used for IP addresses
			cell.textLabel?.text = entry.domain
		} else {
			cell.textLabel?.attributedText = NSMutableAttributedString(string: entry.domain)
				.withColor(.darkGray, fromBack: parentDomain.count + 1)
		}
		cell.detailTextLabel?.text = entry.detailCellText
		cell.imageView?.image = entry.options?.tableRowImage()
		return cell
	}
}
