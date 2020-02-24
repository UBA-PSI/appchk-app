import UIKit
import NetworkExtension


class TVCDomains: UITableViewController {
	
	private let appDelegate = UIApplication.shared.delegate as! AppDelegate
	private var dataSource: [GroupedDomain] = []
	@IBOutlet private var welcomeMessage: UITextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.welcomeMessage.frame.size.height = 0
//		AppInfoType.initWorkingDir()
		
		NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { [weak self] notification in
			self?.changeState((notification.object as? NETunnelProviderSession)?.status ?? .invalid)
		}
		NotificationCenter.default.addObserver(forName: .init("ChangedStateGlassVPN"), object: nil, queue: OperationQueue.main) { [weak self] notification in
			self?.changeState((notification.object as? NEVPNStatus) ?? .invalid)
		}
		
		// pull-to-refresh
		tableView.refreshControl = UIRefreshControl()
		tableView.refreshControl?.addTarget(self, action: #selector(reloadDataSource(_:)), for: .valueChanged)
		performSelector(inBackground: #selector(reloadDataSource(_:)), with: nil)
		NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
			self?.reloadDataSource(nil)
		}
//		navigationItem.leftBarButtonItem?.title = "\u{2699}\u{0000FE0E}☰"
//		navigationItem.leftBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.font : UIFont.systemFont(ofSize: 32)], for: .normal)
	}
	
	@IBAction func clickToolbarLeft(_ sender: Any) {
		let alert = UIAlertController(title: "Clear results?",
									  message: "You are about to delete all results that have been logged in the past. Continue?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
			try? SQLiteDatabase.open(path: DB_PATH).destroyContent()
			self?.reloadDataSource(nil)
		}))
		self.present(alert, animated: true, completion: nil)
	}
	
	@IBAction func clickToolbarRight(_ sender: Any) {
		let active = (self.navigationItem.rightBarButtonItem?.tag == NEVPNStatus.connected.rawValue)
		let alert = UIAlertController(title: "\(active ? "Dis" : "En")able Proxy?",
									  message: "The VPN proxy is currently \(active ? "en" : "dis")abled, do you want to proceed and \(active ? "dis" : "en")able logging?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		alert.addAction(UIAlertAction(title: active ? "Disable" : "Enable", style: .default, handler: { [weak self] _ in
			self?.appDelegate.setProxyEnabled(!active)
		}))
		self.present(alert, animated: true, completion: nil)
	}
	
	func changeState(_ newState: NEVPNStatus) {
		let stateView = self.navigationItem.rightBarButtonItem
		if stateView?.tag == newState.rawValue {
			return // don't need to change, already correct state
		}
		stateView?.tag = newState.rawValue
		switch newState {
		case .connected:
			stateView?.title = "Active"
			stateView?.tintColor = .systemGreen
		case .connecting, .disconnecting, .reasserting:
			stateView?.title = "Updating"
			stateView?.tintColor = .systemYellow
		case .invalid, .disconnected:
			fallthrough
		@unknown default:
			stateView?.title = "Inactive"
			stateView?.tintColor = .systemRed
		}
//		let newButton = UIBarButtonItem(barButtonSystemItem: (active ? .pause : .play), target: self, action: #selector(clickToolbarRight(_:)))
//		newButton.tintColor = (active ? .systemRed : .systemGreen)
//		newButton.tag = (active ? 1 : 0)
//		self.navigationItem.setRightBarButton(newButton, animated: true)
	}
	
	private func updateCellAt(_ index: Int) {
		DispatchQueue.main.async {
			guard index >= 0 else {
				self.welcomeMessage.frame.size.height = (self.dataSource.count == 0 ? self.view.frame.size.height : 0)
				self.tableView.reloadData()
				return
			}
			if let idx = self.tableView.indexPathsForVisibleRows?.first(where: { indexPath -> Bool in
				indexPath.row == index
			}) {
				self.tableView.reloadRows(at: [idx], with: .automatic)
			}
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			let dom = dataSource[index].label
			segue.destination.navigationItem.prompt = dom
			(segue.destination as? TVCHosts)?.domain = dom
		}
	}
	
	
	// MARK: - Table View Delegate
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DomainCell")!
		let entry = dataSource[indexPath.row]
		let last = Date.init(timeIntervalSince1970: Double(entry.lastModified))
		
		cell.textLabel?.text = entry.label
		cell.detailTextLabel?.text = "\(dateFormatter.string(from: last))   —   \(entry.count)"
		return cell
	}
	
	
	// MARK: - Data Source
	
	@objc private func reloadDataSource(_ sender : Any?) {
		self.dataSource = self.sqliteAppList()
		if let refreshControl = sender as? UIRefreshControl {
			DispatchQueue.main.async { refreshControl.endRefreshing() }
		}
		self.updateCellAt(-1)
	}
	
	private func sqliteAppList() -> [GroupedDomain] {
		guard let db = try? SQLiteDatabase.open(path: DB_PATH) else {
			return []
		}
		return db.domainList()
	}
}
