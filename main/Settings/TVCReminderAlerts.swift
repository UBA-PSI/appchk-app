import UIKit

class TVCReminderAlerts: UITableViewController {
	
	@IBOutlet var restartAllow: UISwitch!
	@IBOutlet var restartAllowNotify: UISwitch!
	@IBOutlet var restartAllowBadge: UISwitch!
	@IBOutlet var restartSound: UITableViewCell!
	
	@IBOutlet var recordingAllow: UISwitch!
	@IBOutlet var recordingSound: UITableViewCell!
	
	private enum ReminderCellType { case Restart, Recording }
	private var selectedSound: ReminderCellType = .Restart
	
	override func viewDidLoad() {
		super.viewDidLoad()
		restartAllowNotify.isOn = PrefsShared.RestartReminder.WithText
		restartAllowBadge.isOn = PrefsShared.RestartReminder.WithBadge
		restartSound.detailTextLabel?.text = AlertSoundTitle(for: PrefsShared.RestartReminder.Sound)
		recordingSound.detailTextLabel?.text = AlertSoundTitle(for: Prefs.RecordingReminder.Sound)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		readNotificationState { (allowStart, allowRecord, isProvisional) in
			self.cascadeEnableRestart(allowStart && !isProvisional)
			self.recordingAllow.isOn = (allowRecord && !isProvisional)
			self.setIndicateProvisional(isProvisional)
		}
	}
	
	private func readNotificationState(_ closure: @escaping (Bool, Bool, Bool) -> Void) {
		let en1 = PrefsShared.RestartReminder.Enabled
		let en2 = Prefs.RecordingReminder.Enabled
		closure(en1, en2, false)
		guard en1 || en2 else { return }
		PushNotification.allowed { state in
			switch state {
			case .NotDetermined, .Denied: closure(false, false, false)
			case .Authorized, .Provisional: closure(en1, en2, state == .Provisional)
			}
		}
	}
	
	private func cascadeEnableRestart(_ flag: Bool) {
		restartAllow.isOn = flag
		restartAllowNotify.isEnabled = flag
		restartAllowBadge.isEnabled = flag
	}
	
	private func setIndicateProvisional(_ flag: Bool) {
		if flag {
			restartAllow.thumbTintColor = .systemGreen
			recordingAllow.thumbTintColor = .systemGreen
		} else {
			// thumb tint is only set in provisional mode
			if restartAllow.thumbTintColor <-? nil { restartAllow.isOn = true }
			if recordingAllow.thumbTintColor <-? nil { recordingAllow.isOn = true }
		}
	}
	
	private func updateBadge() {
		let flag = (restartAllow.isOn && restartAllowBadge.isOn && GlassVPN.state != .on)
		UIApplication.shared.applicationIconBadgeNumber = flag ? 1 : 0
	}
}


// MARK: - Toggles
	
extension TVCReminderAlerts {
	@IBAction private func toggleAllowRestartReminder(_ sender: UISwitch) {
		PrefsShared.RestartReminder.Enabled = sender.isOn
		cascadeEnableRestart(sender.isOn)
		updateBadge()
		if sender.isOn {
			askAuthorization {}
		} else {
			PushNotification.cancel(.CantStopMeNowReminder)
		}
	}
	
	@IBAction private func toggleAllowRestartNotify(_ sender: UISwitch) {
		PrefsShared.RestartReminder.WithText = sender.isOn
		if !sender.isOn {
			PushNotification.cancel(.CantStopMeNowReminder)
		}
	}
	
	@IBAction private func toggleAllowRestartBadge(_ sender: UISwitch) {
		PrefsShared.RestartReminder.WithBadge = sender.isOn
		updateBadge()
	}
	
	@IBAction private func toggleAllowRecordingReminder(_ sender: UISwitch) {
		Prefs.RecordingReminder.Enabled = sender.isOn
		if sender.isOn {
			askAuthorization { PushNotification.scheduleRecordingReminder(force: false) }
		} else {
			PushNotification.cancel(.YouShallRecordMoreReminder)
		}
	}
	
	private func askAuthorization(_ closure: @escaping () -> Void) {
		setIndicateProvisional(false)
		PushNotification.requestAuthorization { granted in
			if granted {
				closure()
			} else {
				NotificationsDisabledAlert(presentIn: self)
				self.cascadeEnableRestart(false)
				self.recordingAllow.isOn = false
			}
		}
	}
}


// MARK: - Sound Selection

extension TVCReminderAlerts: NotificationSoundChangedDelegate {
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let tvc = segue.destination as? TVCChooseAlertTone {
			switch segue.identifier {
			case "segueSoundRestartReminder":   selectedSound = .Restart
			case "segueSoundRecordingReminder": selectedSound = .Recording
			default: preconditionFailure()
			}
			tvc.delegate = self
		}
	}
	
	func notificationSoundCurrent() -> String {
		switch selectedSound {
		case .Restart: return PrefsShared.RestartReminder.Sound
		case .Recording: return Prefs.RecordingReminder.Sound
		}
	}
	
	func notificationSoundChanged(filename: String, title: String) {
		switch selectedSound {
		case .Restart:
			restartSound.detailTextLabel?.text = title
			PrefsShared.RestartReminder.Sound = filename
		case .Recording:
			recordingSound.detailTextLabel?.text = title
			Prefs.RecordingReminder.Sound = filename
			if Prefs.RecordingReminder.Enabled {
				PushNotification.scheduleRecordingReminder(force: true)
			}
		}
	}
}
