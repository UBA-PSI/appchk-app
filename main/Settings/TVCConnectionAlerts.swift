import UIKit

class TVCConnectionAlerts: UITableViewController {
	
	@IBOutlet var showNotifications: UISwitch!
	@IBOutlet var cellSound: UITableViewCell!
	
	@IBOutlet var listsCustomA: UITableViewCell!
	@IBOutlet var listsCustomB: UITableViewCell!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		cascadeEnableConnAlert(PrefsShared.ConnectionAlerts.Enabled)
		cellSound.detailTextLabel?.text = AlertSoundTitle(for: PrefsShared.ConnectionAlerts.Sound)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		let (_, _, custA, custB) = DomainFilter.counts()
		listsCustomA.detailTextLabel?.text = "\(custA) Domains"
		listsCustomB.detailTextLabel?.text = "\(custB) Domains"
	}
	
	private func cascadeEnableConnAlert(_ flag: Bool) {
		showNotifications.isOn = flag
		// en/disable related controls
	}
	
	private func getListSelected(_ index: Int) -> Bool {
		switch index {
		case 0: return PrefsShared.ConnectionAlerts.Lists.Blocked
		case 1: return PrefsShared.ConnectionAlerts.Lists.CustomA
		case 2: return PrefsShared.ConnectionAlerts.Lists.CustomB
		case 3: return PrefsShared.ConnectionAlerts.Lists.Else
		default: preconditionFailure()
		}
	}
	
	private func setListSelected(_ index: Int, _ value: Bool) {
		switch index {
		case 0: PrefsShared.ConnectionAlerts.Lists.Blocked = value
		case 1: PrefsShared.ConnectionAlerts.Lists.CustomA = value
		case 2: PrefsShared.ConnectionAlerts.Lists.CustomB = value
		case 3: PrefsShared.ConnectionAlerts.Lists.Else = value
		default: preconditionFailure()
		}
	}
	
	// MARK: - Toggles
	
	@IBAction private func toggleShowNotifications(_ sender: UISwitch) {
		PrefsShared.ConnectionAlerts.Enabled = sender.isOn
		cascadeEnableConnAlert(sender.isOn)
		GlassVPN.send(.notificationSettingsChanged())
		if sender.isOn {
			PushNotification.requestAuthorization { granted in
				if !granted {
					NotificationsDisabledAlert(presentIn: self)
					self.cascadeEnableConnAlert(false)
				}
			}
		} else {
			PushNotification.cancel(.AllConnectionAlertNotifications)
		}
	}
	
	// MARK: - Table View Delegate
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)
		let checked: Bool
		switch indexPath.section {
		case 1: // mode selection
			checked = (indexPath.row == (PrefsShared.ConnectionAlerts.ExcludeMode ? 1 : 0))
		case 2: // include & exclude lists
			checked = getListSelected(indexPath.row)
		default: return cell // process only checkmarked cells
		}
		cell.accessoryType = checked ? .checkmark : .none
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.section {
		case 1: // mode selection
			PrefsShared.ConnectionAlerts.ExcludeMode = indexPath.row == 1
			tableView.reloadSections(.init(integer: 2), with: .none)
		case 2: // include & exclude lists
			let prev = tableView.cellForRow(at: indexPath)?.accessoryType == .checkmark
			setListSelected(indexPath.row, !prev)
		default: return // process only checkmarked cells
		}
		tableView.deselectRow(at: indexPath, animated: true)
		tableView.reloadSections(.init(integer: indexPath.section), with: .none)
		GlassVPN.send(.notificationSettingsChanged())
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 2 {
			return PrefsShared.ConnectionAlerts.ExcludeMode ? "Exclude All" : "Include All"
		}
		return super.tableView(tableView, titleForHeaderInSection: section)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let dest = segue.destination as? TVCFilter {
			switch segue.identifier {
			case "segueFilterListCustomA":
				dest.navigationItem.title = "Custom List A"
				dest.currentFilter = .customA
			case "segueFilterListCustomB":
				dest.navigationItem.title = "Custom List B"
				dest.currentFilter = .customB
			default:
				break
			}
		} else if let tvc = segue.destination as? TVCChooseAlertTone {
			tvc.delegate = self
		}
	}
}

// MARK: - Sound Selection

extension TVCConnectionAlerts: NotificationSoundChangedDelegate {
	func notificationSoundCurrent() -> String {
		PrefsShared.ConnectionAlerts.Sound
	}
	
	func notificationSoundChanged(filename: String, title: String) {
		cellSound.detailTextLabel?.text = title
		PrefsShared.ConnectionAlerts.Sound = filename
		GlassVPN.send(.notificationSettingsChanged())
	}
}
