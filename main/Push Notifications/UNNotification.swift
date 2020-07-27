import UserNotifications

enum NotificationRequestState {
	case NotDetermined, Denied, Authorized, Provisional
	@available(iOS 10.0, *)
	init(_ from: UNAuthorizationStatus) {
		switch from {
		case .denied: self = .Denied
		case .authorized: self = .Authorized
		case .provisional: self = .Provisional
		case .notDetermined: fallthrough
		@unknown default: self = .NotDetermined
		}
	}
}

@available(iOS 10.0, *)
extension UNNotificationRequest {
	func push() {
		UNUserNotificationCenter.current().add(self) { error in
			if let e = error {
				NSLog("[ERROR] Can't add push notification: \(e)")
			}
		}
	}
	func pushAndWait() {
		let semaphore = DispatchSemaphore(value: 0)
		UNUserNotificationCenter.current().add(self) { error in
			if let e = error {
				NSLog("[ERROR] Can't add push notification: \(e)")
			}
			semaphore.signal()
		}
		_ = semaphore.wait(wallTimeout: .distantFuture)
	}
}

@available(iOS 10.0, *)
extension UNNotificationContent {
	/// - Parameter sound: Use `#default` or `nil`  to play the default tone. Use `#mute` to play no tone at all. Else use an `UNNotificationSoundName`.
	static func make(_ title: String, body: String, sound: UNNotificationSound? = .default) -> UNNotificationContent {
		let x = UNMutableNotificationContent()
		// use NSString.localizedUserNotificationString(forKey:arguments:)
		x.title = title
		x.body = body
		x.sound = sound
		return x
	}
	/// - Parameter value: `0` will remove the badge
	static func makeBadge(_ value: Int) -> UNNotificationContent {
		let x = UNMutableNotificationContent()
		x.badge = value as NSNumber?
		return x
	}
}

@available(iOS 10.0, *)
extension UNNotificationTrigger {
	/// Calls `(dateMatching: components, repeats: repeats)`
	static func make(_ components: DateComponents, repeats: Bool) -> UNCalendarNotificationTrigger {
		UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
	}
	/// Calls `(dateMatching: components(second-year), repeats: false)`
	static func make(_ date: Date) -> UNCalendarNotificationTrigger {
		let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
		return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
	}
	/// Calls `(timeInterval: time, repeats: repeats)`
	static func make(_ time: TimeInterval, repeats: Bool) -> UNTimeIntervalNotificationTrigger {
		UNTimeIntervalNotificationTrigger(timeInterval: time, repeats: repeats)
	}
}

@available(iOS 10.0, *)
extension UNNotificationSound {
	static func from(string: String) -> UNNotificationSound? {
		switch string {
		case "#mute":    return nil
		case "#default": return .default
		case let name:   return .init(named: UNNotificationSoundName(name + ".caf"))
		}
	}
}
