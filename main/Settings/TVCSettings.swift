import UIKit

class TVCSettings: UITableViewController {
	
	private let appDelegate = UIApplication.shared.delegate as! AppDelegate
	@IBOutlet var vpnToggle: UISwitch!
	@IBOutlet var cellDomainsIgnored: UITableViewCell!
	@IBOutlet var cellDomainsBlocked: UITableViewCell!
	@IBOutlet var cellPrivacyAutoDelete: UITableViewCell!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		reloadToggleState()
		reloadDataSource()
		NotifyVPNStateChanged.observe(call: #selector(reloadToggleState), on: self)
		NotifyDNSFilterChanged.observe(call: #selector(reloadDataSource), on: self)
	}
	
	
	// MARK: - VPN Proxy Settings
	
	@IBAction private func toggleVPNProxy(_ sender: UISwitch) {
		GlassVPN.setEnabled(sender.isOn)
	}
	
	@objc private func reloadToggleState() {
		vpnToggle.isOn = (GlassVPN.state != .off)
		vpnToggle.onTintColor = (GlassVPN.state == .inbetween ? .systemYellow : nil)
	}
	
	
	// MARK: - Logging Filter
	
	@objc private func reloadDataSource() {
		let (blocked, ignored) = DomainFilter.counts()
		cellDomainsIgnored.detailTextLabel?.text = "\(ignored) Domains"
		cellDomainsBlocked.detailTextLabel?.text = "\(blocked) Domains"
		let (one, two) = autoDeleteSelection([1, 7, 31])
		cellPrivacyAutoDelete.detailTextLabel?.text = autoDeleteString(one, unit: two)
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
	
	
	// MARK: - Privacy
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let cell = tableView.cellForRow(at: indexPath), cell === cellPrivacyAutoDelete {
			let multiplier = [1, 7, 31]
			let (one, two) = autoDeleteSelection(multiplier)
			
			let picker = DurationPickerAlert(
				title: "Auto-delete logs",
				detail: "Logs will be deleted on app launch or periodically as long as the VPN is running.",
				options: [(0...30).map{"\($0)"}, ["Days", "Weeks", "Months"]],
				widths: [0.4, 0.6])
			picker.pickerView.setSelection([min(30, one), two])
			picker.present(in: self) {
				PrefsShared.AutoDeleteLogsDays = $1[0] * multiplier[$1[1]]
				cell.detailTextLabel?.text = autoDeleteString($1[0], unit: $1[1])
				// TODO: notify VPN and local delete timer
			}
		}
	}
	
	
	// MARK: - Reset Settings
	
	@IBAction private func resetTutorialAlerts(_ sender: UIButton) {
		Prefs.DidShowTutorial.Welcome = false
		Prefs.DidShowTutorial.Recordings = false
		Alert(title: sender.titleLabel?.text,
			  text: "\nDone.\n\nYou may need to restart the application.").presentIn(self)
	}
	
	@IBAction private func clearDatabaseResults() {
		AskAlert(title: "Clear results?", text:
			"You are about to delete all results that have been logged in the past. " +
			"Your preferences for blocked and ignored domains are preserved.\n" +
			"Continue?", buttonText: "Delete", buttonStyle: .destructive) { _ in
				TheGreatDestroyer.deleteAllLogs()
		}.presentIn(self)
	}
	
	
	// MARK: - Advanced
	
	@IBAction private func exportDB() {
		let sheet = UIActivityViewController(activityItems: [URL.internalDB()], applicationActivities: nil)
		self.present(sheet, animated: true)
	}
}


//  -------------------------------
// |
// |    MARK: - Helper methods
// |
//  -------------------------------

private func autoDeleteSelection(_ multiplier: [Int]) -> (Int, Int) {
	let current = PrefsShared.AutoDeleteLogsDays
	let snd = multiplier.lastIndex { current % $0 == 0 }! // make sure 1 is in list
	return (current / multiplier[snd], snd)
}

private func autoDeleteString(_ num: Int, unit: Int) -> String {
	switch num {
	case 0:  return "Never"
	case 1:  return "1 \(["Day", "Week", "Month"][unit])"
	default: return "\(num) \(["Days", "Weeks", "Months"][unit])"
	}
}
