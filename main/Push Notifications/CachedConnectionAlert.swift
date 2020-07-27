import Foundation
import UserNotifications

struct CachedConnectionAlert {
	let enabled: Bool
	let invertedMode: Bool
	let listBlocked, listCustomA, listCustomB, listElse: Bool
	let tone: AnyObject?
	
	init() {
		enabled = PrefsShared.ConnectionAlerts.Enabled
		guard #available(iOS 10.0, *), enabled else {
			invertedMode = false
			listBlocked = false
			listCustomA = false
			listCustomB = false
			listElse = false
			tone = nil
			return
		}
		invertedMode = PrefsShared.ConnectionAlerts.ExcludeMode
		listBlocked = PrefsShared.ConnectionAlerts.Lists.Blocked
		listCustomA = PrefsShared.ConnectionAlerts.Lists.CustomA
		listCustomB = PrefsShared.ConnectionAlerts.Lists.CustomB
		listElse = PrefsShared.ConnectionAlerts.Lists.Else
		tone = UNNotificationSound.from(string: PrefsShared.ConnectionAlerts.Sound)
	}
	
	/// If notifications are enabled and allowed, schedule new notification. Otherwise NOOP.
	/// - Parameters:
	///   - domain: Domain will be used as unique identifier for noticiation center and in notification message.
	///   - blck: Indicator whether `domain` is part of `blocked` list
	///   - custA: Indicator whether `domain` is part of custom list `A`
	///   - custB: Indicator whether `domain` is part of custom list `B`
	func postOrIgnore(_ domain: String, blck: Bool, custA: Bool, custB: Bool) {
		if #available(iOS 10.0, *), enabled {
			let onAnyList = listBlocked && blck || listCustomA && custA || listCustomB && custB || listElse
			if invertedMode ? !onAnyList : onAnyList {
				PushNotification.scheduleConnectionAlert(domain, sound: tone as! UNNotificationSound?)
			}
		}
	}
}
