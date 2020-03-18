import UIKit

class TVCSettings: UITableViewController {
	
	private let appDelegate = UIApplication.shared.delegate as! AppDelegate
	@IBOutlet var vpnToggle: UISwitch!
	@IBOutlet var cellDomainsIgnored: UITableViewCell!
	@IBOutlet var cellDomainsBlocked: UITableViewCell!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		NotifyVPNStateChanged.observe(call: #selector(vpnStateChanged(_:)), on: self)
		changedState(currentVPNState)
		NotifyFilterChanged.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
	}
	
	@objc func reloadDataSource() {
		let (blocked, ignored) = DBWrp.dataF_counts()
		DispatchQueue.main.async {
			self.cellDomainsIgnored.detailTextLabel?.text = "\(ignored) Domains"
			self.cellDomainsBlocked.detailTextLabel?.text = "\(blocked) Domains"
		}
	}
	
	@IBAction func toggleVPNProxy(_ sender: UISwitch) {
		appDelegate.setProxyEnabled(sender.isOn)
	}
	
	@IBAction func exportDB(_ sender: Any) {
		// TODO: export partly?
		// TODO: show header-banner of success
		// Share Sheet
		let sheet = UIActivityViewController(activityItems: [URL(fileURLWithPath: DB_PATH)], applicationActivities: nil)
		self.present(sheet, animated: true)
		// Save to Files app
//		self.present(UIDocumentPickerViewController(url: URL(fileURLWithPath: DB_PATH), in: .exportToService), animated: true)
		// Shows Alert and exports to Documents directory
//		AskAlert(title: "Export results?", text: """
//			This action will copy the internal database to the app's local Documents directory. You can use the Files app to access the database file.
//
//			Note: This will make your DNS requests available to other apps!
//		""", buttonText: "Export") {
//			do {
//				let dest = try SQLiteDatabase.export()
//				let folder = dest.deletingLastPathComponent()
//				let out = folder.lastPathComponent + "/" + dest.lastPathComponent
//				Alert(title: "Successful", text: "File exported to '\(out)'", buttonText: "OK").presentIn(self)
//			} catch {
//				ErrorAlert(error).presentIn(self)
//			}
//		}.presentIn(self)
	}
	
	@IBAction func clearDatabaseResults(_ sender: Any) {
		AskAlert(title: "Clear results?", text: """
			You are about to delete all results that have been logged in the past. Your preference for blocked and ignored domains is preserved.
			Continue?
		""", buttonText: "Delete", buttonStyle: .destructive) {
			DBWrp.deleteHistory()
		}.presentIn(self)
	}
	
	@objc func vpnStateChanged(_ notification: Notification) {
		changedState(notification.object as! VPNState)
	}
	
	func changedState(_ newState: VPNState) {
		vpnToggle.isOn = (newState != .off)
		vpnToggle.onTintColor = (newState == .inbetween ? .systemYellow : nil)
	}
	
	override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
		let t:String, d: String
		switch tableView.cellForRow(at: indexPath)?.reuseIdentifier {
		case "settingsIgnoredCell":
			t = "Ignored Domains"
			d = "Ignored domains won't show up in session recordings nor in the requests overview. Requests to ignored domains are not logged."
		case "settingsBlockedCell":
			t = "Blocked Domains"
			d = "Blocked domains prohibit all requests to that domain. Unless a domain is also ignored, the request will be logged and appear in session recordings and the requests overview."
		default: return
		}
		Alert(title: t, text: d).presentIn(self)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let dest = (segue.destination as? TVCFilter) else { return }
		switch segue.identifier {
		case "segueFilterIgnored":
			dest.navigationItem.title = "Ignored Domains"
			dest.currentFilter = .ignored
		case "segueFilterBlocked":
			dest.navigationItem.title = "Blocked Domains"
			dest.currentFilter = .blocked
		default:
			break
		}
	}
}
