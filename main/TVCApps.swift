import UIKit



class TVCApps: UITableViewController {
	
	private let appDelegate = UIApplication.shared.delegate as! AppDelegate
	private var dataSource: [AppInfoType] = []
	@IBOutlet private var welcomeMessage: UITextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.welcomeMessage.frame.size.height = 0
		AppInfoType.initWorkingDir()
		
		NotificationCenter.default.addObserver(forName: .init("ChangedStateGlassDNS"), object: nil, queue: OperationQueue.main) { [weak self] notification in
//			let stateView = self.navigationItem.rightBarButtonItem?.customView as? ProxyStateView
//			stateView?.status = (notification.object as! Bool ? .running : .stopped)
//			let active = notification.object as! Bool
			self?.changeState(notification.object as! Bool)
		}
		// pull-to-refresh
//		tableView.refreshControl = UIRefreshControl()
//		tableView.refreshControl?.addTarget(self, action: #selector(reloadDataSource(_:)), for: .valueChanged)
//		performSelector(inBackground: #selector(reloadDataSource(_:)), with: nil)
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
		let inactive = (self.navigationItem.rightBarButtonItem?.tag == 0)
		let alert = UIAlertController(title: "\(inactive ? "En" : "Dis")able Proxy?",
									  message: "The DNS proxy is currently \(inactive ? "dis" : "en")abled, do you want to proceed and \(inactive ? "en" : "dis")able logging?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		alert.addAction(UIAlertAction(title: inactive ? "Enable" : "Disable", style: .default, handler: { [weak self] _ in
			self?.changeState(inactive)
			self?.appDelegate.setProxyEnabled(inactive)
		}))
		self.present(alert, animated: true, completion: nil)
	}
	
	func changeState(_ active: Bool) {
		let stateView = self.navigationItem.rightBarButtonItem
		if stateView?.tag == 0 && !active,
			stateView?.tag == 1 && active {
			return // don't need to change, already correct state
		}
		stateView?.tag = (active ? 1 : 0)
		stateView?.title = (active ? "Active" : "Inactive")
		stateView?.tintColor = (active ? .systemGreen : .systemRed)
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
			let info = dataSource[index]
			segue.destination.navigationItem.prompt = info.name ?? info.id
			(segue.destination as? TVCRequests)?.appBundleId = info.id
		}
	}
	
	
	// MARK: - Table View Delegate
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "AppBundleCell")!
		let appBundle = dataSource[indexPath.row]
		cell.textLabel?.text = appBundle.name ?? appBundle.id
		cell.detailTextLabel?.text = appBundle.seller
		
		cell.imageView?.image = appBundle.getImage()
		cell.imageView?.layer.cornerRadius = 6.75
		cell.imageView?.layer.masksToBounds = true
		return cell
	}
	
	
	// MARK: - Data Source
	
	@objc private func reloadDataSource(_ sender : Any?) {
		DispatchQueue.global().async {
			self.dataSource = self.sqliteAppList().map { AppInfoType(id: $0) } // will load from HD
			self.updateCellAt(-1)
			for i in self.dataSource.indices {
				self.dataSource[i].updateIfNeeded { [weak self] in
					self?.updateCellAt(i)
				}
			}
			if let refreshControl = sender as? UIRefreshControl {
				refreshControl.endRefreshing()
			}
		}
	}
	
	private func sqliteAppList() -> [String] {
//		return ["unkown", "com.apple.Fitness", "com.apple.AppStore", "com.apple.store.Jolly", "com.apple.supportapp", "com.apple.TVRemote", "com.apple.Bridge", "com.apple.calculator", "com.apple.mobilecal", "com.apple.camera", "com.apple.classroom", "com.apple.clips", "com.apple.mobiletimer", "com.apple.compass", "com.apple.MobileAddressBook", "com.apple.facetime", "com.apple.appleseed.FeedbackAssistant", "com.apple.mobileme.fmf1", "com.apple.mobileme.fmip1", "com.apple.findmy", "com.apple.DocumentsApp", "com.apple.gamecenter", "com.apple.mobilegarageband", "com.apple.Health", "com.apple.Antimony", "com.apple.Home", "com.apple.iBooks", "com.apple.iCloudDriveApp", "com.apple.iMovie", "com.apple.itunesconnect.mobile", "com.apple.MobileStore", "com.apple.itunesu", "com.apple.Keynote", "com.apple.musicapps.remote", "com.apple.mobilemail", "com.apple.Maps", "com.apple.measure", "com.apple.MobileSMS", "com.apple.Music", "com.apple.musicmemos", "com.apple.news", "com.apple.mobilenotes", "com.apple.Numbers", "com.apple.Pages", "com.apple.mobilephone", "com.apple.Photo-Booth", "com.apple.mobileslideshow", "com.apple.Playgrounds", "com.apple.podcasts", "com.apple.reminders", "com.apple.Remote", "com.apple.mobilesafari", "com.apple.Preferences", "is.workflow.my.app", "com.apple.shortcuts", "com.apple.SiriViewService", "com.apple.stocks", "com.apple.tips", "com.apple.movietrailers", "com.apple.tv", "com.apple.videos", "com.apple.VoiceMemos", "com.apple.Passbook", "com.apple.weather", "com.apple.wwdc"]
//		return ["com.apple.backupd", "com.apple.searchd", "com.apple.SafariBookmarksSyncAgent", "com.apple.AppStore", "com.apple.mobilemail", "com.apple.iBooks", "com.apple.icloud.searchpartyd", "com.apple.ap.adprivacyd", "com.apple.bluetoothd", "com.apple.commcentermobilehelper", "com.apple", "com.apple.coreidv.coreidvd", "com.apple.online-auth-agent", "com.apple.tipsd", "com.apple.wifid", "com.apple.captiveagent", "com.apple.pipelined", "com.apple.bird", "com.apple.amfid", "com.apple.nsurlsessiond", "com.apple.Preferences", "com.apple.sharingd", "com.apple.UserEventAgent", "com.apple.healthappd"]
		guard let db = try? SQLiteDatabase.open(path: DB_PATH) else {
			return []
		}
		return db.appList()
	}
}
