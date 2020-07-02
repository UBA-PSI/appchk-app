import UIKit

class TVCHosts: UITableViewController, GroupedDomainDataSourceDelegate, AnalysisBarDelegate {
	
	lazy var source = GroupedDomainDataSource(withParent: parentDomain)
	
	public var parentDomain: String!
	private var isSpecial: Bool = false
	
	override func viewDidLoad() {
		navigationItem.prompt = parentDomain
		super.viewDidLoad()
		isSpecial = (parentDomain.first == "#") // aka: "# IP address"
		source.delegate = self // init lazy var, ready for tableView data source
		source.search.fuseWith(tableViewController: self)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			(segue.destination as? TVCHostDetails)?.fullDomain = source[index].domain
		}
	}
	
	func analysisBarWillOpenCoOccurrence() -> (domain: String, isFQDN: Bool) {
		(parentDomain, false)
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { source.numberOfRows }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HostCell")!
		let entry = source[indexPath.row]
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
	
	func groupedDomainDataSource(needsUpdate row: Int) {
		let entry = source[row]
		let cell = tableView.cellForRow(at: IndexPath(row: row))
		cell?.detailTextLabel?.text = entry.detailCellText
		cell?.imageView?.image = entry.options?.tableRowImage()
	}
}
