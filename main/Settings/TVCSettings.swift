import UIKit

class TVCSettings: UITableViewController {
	
	@IBOutlet var vpnToggle: UISwitch!
	@IBOutlet var cellDomainsIgnored: UITableViewCell!
	@IBOutlet var cellDomainsBlocked: UITableViewCell!
	@IBOutlet var cellPrivacyAutoDelete: UITableViewCell!
	@IBOutlet var cellNotificationReminder: UITableViewCell!
	@IBOutlet var cellNotificationConnectionAlert: UITableViewCell!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		reloadVPNState()
		reloadLoggingFilterUI()
		reloadPrivacyUI()
		NotifyVPNStateChanged.observe(call: #selector(reloadVPNState), on: self)
		NotifyDNSFilterChanged.observe(call: #selector(reloadLoggingFilterUI), on: self)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		reloadNotificationState()
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		// FIXME: there is a lag between tap and open when run on device
		if let cell = tableView.cellForRow(at: indexPath), cell === cellPrivacyAutoDelete {
			openAutoDeletePicker()
		}
	}
	
	func openRestartVPNSettings() { scrollToSection(0, animated: false) }
	func openNotificationSettings() { scrollToSection(2, animated: false) }
	private func scrollToSection(_ section: Int, animated: Bool) {
		tableView.scrollToRow(at: .init(row: 0, section: section), at: .top, animated: animated)
	}
}


// MARK: - VPN Proxy Settings

extension TVCSettings {
	@objc private func reloadVPNState() {
		vpnToggle.isOn = (GlassVPN.state != .off)
		vpnToggle.onTintColor = (GlassVPN.state == .inbetween ? .systemYellow : nil)
		UIApplication.shared.applicationIconBadgeNumber =
			!vpnToggle.isOn &&
			PrefsShared.RestartReminder.Enabled &&
			PrefsShared.RestartReminder.WithBadge ? 1 : 0
	}
	
	@IBAction private func toggleVPNProxy(_ sender: UISwitch) {
		GlassVPN.setEnabled(sender.isOn)
	}
}


// MARK: - Logging Filter

extension TVCSettings {
	@objc private func reloadLoggingFilterUI() {
		let (blocked, ignored, _, _) = DomainFilter.counts()
		cellDomainsIgnored.detailTextLabel?.text = "\(ignored) Domains"
		cellDomainsBlocked.detailTextLabel?.text = "\(blocked) Domains"
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


// MARK: - Privacy

extension TVCSettings {
	private func reloadPrivacyUI() {
		let (num, unit) = getAutoDeleteSelection([1, 7, 31])
		let str: String
		switch num {
		case 0:  str = "Never"
		case 1:  str = "1 \(["Day", "Week", "Month"][unit])"
		default: str = "\(num) \(["Days", "Weeks", "Months"][unit])"
		}
		cellPrivacyAutoDelete.detailTextLabel?.text = str
	}
	
	private func getAutoDeleteSelection(_ multiplier: [Int]) -> (Int, Int) {
		let current = PrefsShared.AutoDeleteLogsDays
		let snd = multiplier.lastIndex { current % $0 == 0 }! // make sure 1 is in list
		return (current / multiplier[snd], snd)
	}
	
	private func openAutoDeletePicker() {
		let multiplier = [1, 7, 31]
		let (one, two) = getAutoDeleteSelection(multiplier)
		
		let picker = DurationPickerAlert(
			title: "Auto-delete logs",
			detail: "Warning: Logs older than the selected interval are deleted immediately! " +
					"Logs are also deleted on each app launch, and periodically in the background as long as the VPN is running.",
			options: [(0...30).map{"\($0)"}, ["Days", "Weeks", "Months"]],
			widths: [0.4, 0.6])
		picker.pickerView.setSelection([min(30, one), two])
		picker.present(in: self) { _, idx in
			let asDays = idx[0] * multiplier[idx[1]]
			PrefsShared.AutoDeleteLogsDays = asDays
			self.reloadPrivacyUI()
			if !GlassVPN.send(.autoDelete(after: asDays)) {
				// if VPN isn't active, fallback to immediate local delete
				TheGreatDestroyer.deleteLogs(olderThan: asDays)
			}
		}
	}
}


// MARK: - Notification Settings

extension TVCSettings {
	private func reloadNotificationState() {
		let lbl1 = cellNotificationReminder.detailTextLabel
		let lbl2 = cellNotificationConnectionAlert.detailTextLabel
		readNotificationState { (realAllowed, provisional) in
			lbl1?.text = provisional ? "Enabled" : "Disabled"
			lbl2?.text = realAllowed ? "Enabled" : "Disabled"
		}
	}
	
	private func readNotificationState(_ closure: @escaping (_ all: Bool, _ prov: Bool) -> Void) {
		let en1 = PrefsShared.ConnectionAlerts.Enabled
		let en2 = Prefs.RecordingReminder.Enabled || PrefsShared.RestartReminder.Enabled
		closure(en1, en2)
		guard en1 || en2 else { return }
		PushNotification.allowed { state in
			switch state {
			case .NotDetermined, .Denied: closure(false, false)
			case .Authorized: closure(en1, en2)
			case .Provisional: closure(false, en2)
			}
		}
	}
}


// MARK: - Reset Settings

extension TVCSettings {
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
}


// MARK: - Advanced

extension TVCSettings {
	@IBAction private func exportDB() {
		AppDB?.vacuum()
		let sheet = UIActivityViewController(activityItems: [URL.internalDB()], applicationActivities: nil)
		self.present(sheet, animated: true)
	}
	
	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == tableView.numberOfSections - 1 {
			let fs = FileManager.default.readableSizeOf(path: URL.internalDB().relativePath)
			return "Database size: \(fs ?? "0 MB")"
		}
		return nil
	}
}
