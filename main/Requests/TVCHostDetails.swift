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
		NotifySyncInsert.observe(call: #selector(syncInsert), on: self)
		NotifySyncRemove.observe(call: #selector(syncRemove), on: self)
		reloadDataSource()
	}
	
	@objc func reloadDataSource(sender: Any? = nil) {
		let refreshControl = sender as? UIRefreshControl
		let notification = sender as? Notification
		if let affectedDomain = notification?.object as? String {
			guard fullDomain.isSubdomain(of: affectedDomain) else { return }
		}
		DispatchQueue.global().async { [weak self] in
			self?.dataSource = AppDB?.timesForDomain(self?.fullDomain ?? "", since: sync.tsEarliest) ?? []
			DispatchQueue.main.sync {
				self?.tableView.reloadData()
				sync.syncNow() // sync outstanding entries in cache
				refreshControl?.endRefreshing()
			}
		}
	}
	
	@objc private func syncInsert(_ notification: Notification) {
		let range = notification.object as! SQLiteRowRange
		if let latest = AppDB?.timesForDomain(fullDomain, range: range), latest.count > 0 {
			dataSource.insert(contentsOf: latest, at: 0)
			if tableView.isFrontmost {
				let indices = (0..<latest.count).map { IndexPath(row: $0) }
				tableView.insertRows(at: indices, with: .left)
			} else {
				tableView.reloadData()
			}
		}
	}
	
	@objc private func syncRemove(_ notification: Notification) {
		let earliest = sync.tsEarliest
		if let i = dataSource.firstIndex(where: { $0.ts < earliest }) {
			// since they are ordered, we can optimize
			let indices = (i..<dataSource.endIndex).map { IndexPath(row: $0) }
			dataSource.removeLast(dataSource.count - i)
			if tableView.isFrontmost {
				tableView.deleteRows(at: indices, with: .automatic)
			} else {
				tableView.reloadData()
			}
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
