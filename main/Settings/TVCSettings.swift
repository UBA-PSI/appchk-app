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
		NotifyDNSFilterChanged.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
	}
	
	@objc func reloadDataSource() {
		let (blocked, ignored) = DomainFilter.counts()
		cellDomainsIgnored.detailTextLabel?.text = "\(ignored) Domains"
		cellDomainsBlocked.detailTextLabel?.text = "\(blocked) Domains"
	}
	
	@IBAction func toggleVPNProxy(_ sender: UISwitch) {
		appDelegate.setProxyEnabled(sender.isOn)
	}
	
	@IBAction func exportDB(_ sender: Any) {
		let sheet = UIActivityViewController(activityItems: [URL.internalDB()], applicationActivities: nil)
		self.present(sheet, animated: true)
	}
	
	@IBAction func resetTutorialAlerts(_ sender: UIButton) {
		Pref.DidShowTutorial.Welcome = false
		Pref.DidShowTutorial.Recordings = false
		Alert(title: sender.titleLabel?.text,
			  text: "\nDone.\n\nYou may need to restart the application.").presentIn(self)
	}
	
	@IBAction func clearDatabaseResults(_ sender: Any) {
		AskAlert(title: "Clear results?", text:
			"You are about to delete all results that have been logged in the past. " +
			"Your preferences for blocked and ignored domains are preserved.\n" +
			"Continue?", buttonText: "Delete", buttonStyle: .destructive) { _ in
				TheGreatDestroyer.deleteAllLogs()
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
