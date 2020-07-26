import Foundation

enum PrefsShared {
	private static var suite: UserDefaults { UserDefaults(suiteName: "group.de.uni-bamberg.psi.AppCheck")! }
	
	private static func Int(_ key: String) -> Int { suite.integer(forKey: key) }
	private static func Int(_ key: String, _ val: Int) { suite.set(val, forKey: key); suite.synchronize() }
	private static func Bool(_ key: String) -> Bool { suite.bool(forKey: key) }
	private static func Bool(_ key: String, _ val: Bool) { suite.set(val, forKey: key); suite.synchronize() }
	private static func Str(_ key: String) -> String? { suite.string(forKey: key) }
	private static func Str(_ key: String, _ val: String?) { suite.set(val, forKey: key); suite.synchronize() }
	
	static func registerDefaults() {
		suite.register(defaults: [
			"RestartReminderEnabled" : true,
			"RestartReminderWithText" : true,
			"RestartReminderWithBadge" : true,
			"ConnectionAlertsListsElse" : true,
		])
	}
	
	static var AutoDeleteLogsDays: Int {
		get { Int("AutoDeleteLogsDays") }
		set { Int("AutoDeleteLogsDays", newValue) }
	}
}


// MARK: - Notifications

extension PrefsShared {
	enum RestartReminder {
		static var Enabled: Bool {
			get { PrefsShared.Bool("RestartReminderEnabled") }
			set { PrefsShared.Bool("RestartReminderEnabled", newValue) }
		}
		static var WithText: Bool {
			get { PrefsShared.Bool("RestartReminderWithText") }
			set { PrefsShared.Bool("RestartReminderWithText", newValue) }
		}
		static var WithBadge: Bool {
			get { PrefsShared.Bool("RestartReminderWithBadge") }
			set { PrefsShared.Bool("RestartReminderWithBadge", newValue) }
		}
		static var Sound: String {
			get { PrefsShared.Str("RestartReminderSound") ?? "#default" }
			set { PrefsShared.Str("RestartReminderSound", newValue) }
		}
	}
	enum ConnectionAlerts {
		static var Enabled: Bool {
			get { PrefsShared.Bool("ConnectionAlertsEnabled") }
			set { PrefsShared.Bool("ConnectionAlertsEnabled", newValue) }
		}
		static var Sound: String {
			get { PrefsShared.Str("ConnectionAlertsSound") ?? "#default" }
			set { PrefsShared.Str("ConnectionAlertsSound", newValue) }
		}
		static var ExcludeMode: Bool {
			get { PrefsShared.Bool("ConnectionAlertsExcludeMode") }
			set { PrefsShared.Bool("ConnectionAlertsExcludeMode", newValue) }
		}
		enum Lists {
			static var CustomA: Bool {
				get { PrefsShared.Bool("ConnectionAlertsListsCustomA") }
				set { PrefsShared.Bool("ConnectionAlertsListsCustomA", newValue) }
			}
			static var CustomB: Bool {
				get { PrefsShared.Bool("ConnectionAlertsListsCustomB") }
				set { PrefsShared.Bool("ConnectionAlertsListsCustomB", newValue) }
			}
			static var Blocked: Bool {
				get { PrefsShared.Bool("ConnectionAlertsListsBlocked") }
				set { PrefsShared.Bool("ConnectionAlertsListsBlocked", newValue) }
			}
			static var Else: Bool {
				get { PrefsShared.Bool("ConnectionAlertsListsElse") }
				set { PrefsShared.Bool("ConnectionAlertsListsElse", newValue) }
			}
		}
	}
}
