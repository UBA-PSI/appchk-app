import UIKit

class TVCHostDetails: UITableViewController, SyncUpdateDelegate {

	public var fullDomain: String!
	private var dataSource: [GroupedTsOccurrence] = []
	// TODO: respect date reverse sort order
	
	override func viewDidLoad() {
		navigationItem.prompt = fullDomain
		super.viewDidLoad()
		sync.addObserver(self) // calls `syncUpdate(reset:)`
		if #available(iOS 10.0, *) {
			sync.allowPullToRefresh(onTVC: self, forObserver: self)
		}
	}
	
	// MARK: - Table View Data Source
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HostDetailCell")!
		let src = dataSource[indexPath.row]
		cell.textLabel?.text = DateFormat.seconds(src.ts)
		cell.detailTextLabel?.text = (src.total > 1) ? "\(src.total)x" : nil
		cell.imageView?.image = (src.blocked > 0 ? UIImage(named: "shield-x") : nil)
		return cell
	}
}

// ################################
// #
// #    MARK: - Partial Update
// #
// ################################

extension TVCHostDetails {
	
	func syncUpdate(_ _: SyncUpdate, reset rows: SQLiteRowRange) {
		dataSource = AppDB?.timesForDomain(fullDomain, range: rows) ?? []
		DispatchQueue.main.sync { tableView.reloadData() }
	}
	
	func syncUpdate(_ _: SyncUpdate, insert rows: SQLiteRowRange) {
		guard let latest = AppDB?.timesForDomain(fullDomain, range: rows), latest.count > 0 else {
			return
		}
		// TODO: if filter will be ever editable at this point, we cannot insert at 0
		dataSource.insert(contentsOf: latest, at: 0)
		DispatchQueue.main.sync {
			if tableView.isFrontmost {
				let indices = (0..<latest.count).map { IndexPath(row: $0) }
				tableView.insertRows(at: indices, with: .left)
			} else {
				tableView.reloadData()
			}
		}
	}
	
	func syncUpdate(_ sender: SyncUpdate, remove _: SQLiteRowRange) {
		let earliest = sender.tsEarliest
		let latest = sender.tsLatest
		// Assuming they are ordered by ts and in descending order
		if let i = dataSource.lastIndex(where: { $0.ts >= earliest }), (i+1) < dataSource.count {
			let indices = ((i+1)..<dataSource.endIndex).map{ $0 }
			dataSource.removeLast(dataSource.count - (i+1))
			DispatchQueue.main.sync { tableView.safeDeleteRows(indices) }
		}
		if let i = dataSource.firstIndex(where: { $0.ts <= latest }), i > 0 {
			let indices = (dataSource.startIndex..<i).map{ $0 }
			dataSource.removeFirst(i)
			DispatchQueue.main.sync { tableView.safeDeleteRows(indices) }
		}
	}
	
	func syncUpdate(_ sender: SyncUpdate, partialRemove affectedDomain: String) {
		if fullDomain.isSubdomain(of: affectedDomain) {
			syncUpdate(sender, reset: sender.rows)
		}
	}
}
