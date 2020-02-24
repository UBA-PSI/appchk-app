import UIKit

class TVCHostDetails: UITableViewController {

	public var domain: String?
	public var host: String?
	private var dataSource: [Timestamp] = []
	
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
		dataSource = []
		guard let dom = domain, let db = try? SQLiteDatabase.open(path: DB_PATH) else {
			return
		}
		dataSource = db.timesForDomain(dom, host: host)
		DispatchQueue.main.async {
			if let refreshControl = sender as? UIRefreshControl {
				refreshControl.endRefreshing()
			}
			self.tableView.reloadData()
		}
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HostDetailCell")!
		let date = Date.init(timeIntervalSince1970: Double(dataSource[indexPath.row]))
		cell.textLabel?.text = dateFormatter.string(from: date)
		return cell
	}
}
