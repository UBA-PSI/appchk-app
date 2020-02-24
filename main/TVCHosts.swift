import UIKit

class TVCHosts: UITableViewController {
	
	private var attributedDomain: NSAttributedString = NSAttributedString(string: "")
	public var domain: String? {
		willSet {
			attributedDomain = NSAttributedString(string: ".\(newValue ?? "")",
				attributes: [.foregroundColor : UIColor.darkGray])
		}
	}
	private var dataSource: [GroupedDomain] = []
	
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
		guard let dom = domain, let db = try? SQLiteDatabase.open(path: DB_PATH) else {
			return
		}
		dataSource = db.hostsForDomain(dom as NSString)
		
//		var list: [String: [Int64]] = [:]
//		db.subdomainsForDomain(appIdentifier: dom as NSString) { query in
////			let x = query.dns.split(separator: ".").reversed().joined(separator: ".")
//			let x = query.host ?? ""
//			if list[x] == nil {
//				list[x] = []
//			}
//			list[x]?.append(query.ts)
//		}
//		dataSource = list.sorted{ $0.0 < $1.0 }
		DispatchQueue.main.async {
			if let refreshControl = sender as? UIRefreshControl {
				refreshControl.endRefreshing()
			}
			self.tableView.reloadData()
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			
			let entry = dataSource[index]
			segue.destination.navigationItem.prompt = "\(entry.label).\(domain ?? "")"
			let vc = (segue.destination as? TVCHostDetails)
			vc?.domain = domain
			vc?.host = entry.label
		}
	}
	
	// MARK: - Data Source
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "HostCell")!
		let entry = dataSource[indexPath.row]
		let last = Date.init(timeIntervalSince1970: Double(entry.lastModified))
		let x = NSMutableAttributedString(string: entry.label)
		x.append(attributedDomain)
		cell.textLabel?.attributedText = x
//		cell.textLabel?.text = "\(entry.label).\(domain ?? "")"
		cell.detailTextLabel?.text = "\(dateFormatter.string(from: last))   —   \(entry.count)"
		return cell
	}
}
