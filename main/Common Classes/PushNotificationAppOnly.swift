import UserNotifications

extension PushNotification {
	static func scheduleRecordingReminder(force: Bool) {
		if force {
			scheduleRecordingReminder()
		} else {
			hasPending(.YouShallRecordMoreReminder) {
				if !$0 { scheduleRecordingReminder() }
			}
		}
	}
		
	private static func scheduleRecordingReminder() {
		guard #available(iOS 10, *) else { return }
		
		let now = Timestamp.now()
		var next = RecordingsDB.lastTimestamp() ?? (now - 1)
		while next < now {
			next += .days(14)
		}
		schedule(.YouShallRecordMoreReminder,
				 content: .make("Start new recording",
								body: "It's been a while since your last recording …",
								sound: .from(string: Prefs.RecordingReminder.Sound)),
				 trigger: .make(Date(next)))
	}
}
