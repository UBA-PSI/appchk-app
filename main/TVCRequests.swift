import UIKit

class TVCRequests: UITableViewController {
	
	public var appBundleId: String? = nil
	private var dataSource: [(String, [Int64])] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// pull-to-refresh
		tableView.refreshControl = UIRefreshControl()
		tableView.refreshControl?.addTarget(self, action: #selector(reloadDataSource(_:)), for: .valueChanged)
		performSelector(inBackground: #selector(reloadDataSource(_:)), with: nil)
		NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
			self?.reloadDataSource(nil)
		}
	}
	
	@objc private func reloadDataSource(_ sender : Any?) {
//		dataSource = [("hi", [1, 2]), ("there", [2, 4, 8, 1580472632]), ("dude", [1, 2, 3])]
//		return ()
		dataSource = []
		guard let bundleId = appBundleId, let db = try? SQLiteDatabase.open(path: DB_PATH) else {
			return
		}
		var list: [String: [Int64]] = [:]
		db.dnsQueriesForApp(appIdentifier: bundleId as NSString) { query in
			let x = query.dns.split(separator: ".").reversed().joined(separator: ".")
			if list[x] == nil {
				list[x] = []
			}
			list[x]?.append(query.ts)
		}
		dataSource = list.sorted{ $0.0 < $1.0 }
		DispatchQueue.main.async {
			self.tableView.reloadData()
			if let refreshControl = sender as? UIRefreshControl {
				refreshControl.endRefreshing()
			}
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			let info = dataSource[index]
			segue.destination.navigationItem.prompt = info.0
			(segue.destination as? TVCRequestDetails)?.dataSource = info.1
		}
	}
	
	// MARK: - Data Source
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "RequestCell")!
		let info = dataSource[indexPath.row]
		cell.textLabel?.text = info.0
		cell.detailTextLabel?.text = "\(info.1.count)"
		return cell
	}
}
