import UserNotifications

struct PushNotification {
	
	enum Identifier: String {
		case YouShallRecordMoreReminder
		case CantStopMeNowReminder
		case RestInPeaceTombstone
		case AllConnectionAlertNotifications
	}
	
	static func allowed(_ closure: @escaping (NotificationRequestState) -> Void) {
		guard #available(iOS 10, *) else { return }
		
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			let state = NotificationRequestState(settings.authorizationStatus)
			DispatchQueue.main.async {
				closure(state)
			}
		}
	}
	
	/// Available in iOS 12+
	static func requestProvisionalOrDoNothing(_ closure: @escaping (Bool) -> Void) {
		guard #available(iOS 12, *) else { return closure(false) }
		
		let opt: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional, .providesAppNotificationSettings]
		UNUserNotificationCenter.current().requestAuthorization(options: opt) { granted, _ in
			DispatchQueue.main.async {
				closure(granted)
			}
		}
	}
	
	static func requestAuthorization(_ closure: @escaping (Bool) -> Void) {
		guard #available(iOS 10, *) else { return }
		
		var opt: UNAuthorizationOptions = [.alert, .sound, .badge]
		if #available(iOS 12, *) {
			opt.formUnion(.providesAppNotificationSettings)
		}
		UNUserNotificationCenter.current().requestAuthorization(options: opt) { granted, _ in
			DispatchQueue.main.async {
				closure(granted)
			}
		}
	}
	
	static func hasPending(_ ident: Identifier, _ closure: @escaping (Bool) -> Void) {
		guard #available(iOS 10, *) else { return }
		
		UNUserNotificationCenter.current().getPendingNotificationRequests {
			let hasIt = $0.contains { $0.identifier == ident.rawValue }
			DispatchQueue.main.async {
				closure(hasIt)
			}
		}
	}
	
	static func cancel(_ ident: Identifier, keepDelivered: Bool = false) {
		guard #available(iOS 10, *) else { return }
		
		let center = UNUserNotificationCenter.current()
		guard ident != .AllConnectionAlertNotifications else {
			// remove all connection alert notifications while
			// keeping general purpose reminder notifications
			center.getDeliveredNotifications {
				var list = $0.map { $0.request.identifier }
				list.removeAll { !$0.contains(".") } // each domain (or IP) has a dot
				center.removeDeliveredNotifications(withIdentifiers: list)
				// no need to do the same for pending since con-alerts are always immediate
			}
			return
		}
		center.removePendingNotificationRequests(withIdentifiers: [ident.rawValue])
		if !keepDelivered {
			center.removeDeliveredNotifications(withIdentifiers: [ident.rawValue])
		}
	}
	
	@available(iOS 10.0, *)
	static func schedule(_ ident: Identifier, content: UNNotificationContent, trigger: UNNotificationTrigger? = nil, waitUntilDone: Bool = false) {
		schedule(ident.rawValue, content: content, trigger: trigger, waitUntilDone: waitUntilDone)
	}
	
	@available(iOS 10.0, *)
	static func schedule(_ ident: String, content: UNNotificationContent, trigger: UNNotificationTrigger? = nil, waitUntilDone: Bool = false) {
		let req = UNNotificationRequest(identifier: ident, content: content, trigger: trigger)
		waitUntilDone ? req.pushAndWait() : req.push()
	}
}


// MARK: - Reminder Alerts

extension PushNotification {
	/// Auto-check preferences whether `withText` is set, then schedule notification to 5 min in the future.
	static func scheduleRestartReminderBanner() {
		guard #available(iOS 10, *), PrefsShared.RestartReminder.WithText else { return }
		
		schedule(.CantStopMeNowReminder,
				 content: .make("AppChk disabled",
								body: "AppChk can't monitor network traffic because VPN has stopped.",
								sound: .from(string: PrefsShared.RestartReminder.Sound)),
				 trigger: .make(Date(timeIntervalSinceNow: 5 * 60)),
				 waitUntilDone: true)
	}
	
	/// Auto-check preferences whether `withBadge` is set, then post badge immediatelly.
	/// - Parameter on: If `true`, set `1` on app icon. If `false`, remove badge on app icon.
	static func scheduleRestartReminderBadge(on: Bool) {
		guard #available(iOS 10, *), PrefsShared.RestartReminder.WithBadge else { return }
		
		schedule(.RestInPeaceTombstone, content: .makeBadge(on ? 1 : 0), waitUntilDone: true)
	}
}


// MARK: - Connection Alerts

extension PushNotification {
	static private let queue = ThrottledBatchQueue<String>(0.5, using: .init(label: "PSINotificationQueue", qos: .default, target: .global()))
	
	/// Post new notification with given domain name. If notification already exists, increase occurrence count.
	/// - Parameter domain: Used in the description and as notification identifier.
	@available(iOS 10.0, *)
	static func scheduleConnectionAlert(_ domain: String, sound: UNNotificationSound?) {
		queue.addDelayed(domain) { batch in
			let groupSum = batch.reduce(into: [:]) { $0[$1] = ($0[$1] ?? 0) + 1 }
			scheduleConnectionAlertMulti(groupSum, sound: sound)
		}
	}
	
	/// Internal method to post a batch of counted domains.
	@available(iOS 10.0, *)
	static private func scheduleConnectionAlertMulti(_ group: [String: Int], sound: UNNotificationSound?) {
		UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
			for (dom, count) in group {
				let num: Int
				if let prev = delivered.first(where: { $0.request.identifier == dom })?.request.content {
					if let p = prev.body.split(separator: "×").first, let i = Int(p) {
						num = count + i
					} else {
						num = count + 1
					}
				} else {
					num = count
				}
				schedule(dom, content: .make("DNS connection", body: num > 1 ? "\(num)× \(dom)" : dom, sound: sound))
			}
		}
	}
}
