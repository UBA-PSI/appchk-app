import UIKit

class TVCHosts: UITableViewController, FilterPipelineDelegate {
	
	lazy var source = GroupedDomainDataSource(withDelegate: self, parent: parentDomain)
	
	public var parentDomain: String!
	private var isSpecial: Bool = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.prompt = parentDomain
		isSpecial = (parentDomain.first == "#") // aka: "# IP address"
		source.reloadFromSource() // init lazy var
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			(segue.destination as? TVCHostDetails)?.fullDomain = source[index].domain
		}
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
	
	func rowNeedsUpdate(_ row: Int) {
		let entry = source[row]
		let cell = tableView.cellForRow(at: IndexPath(row: row))
		cell?.detailTextLabel?.text = entry.detailCellText
		cell?.imageView?.image = entry.options?.tableRowImage()
	}
}
