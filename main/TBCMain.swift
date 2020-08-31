import UIKit
import NetworkExtension

class TBCMain: UITabBarController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		reloadTabBarBadge()
		NotifyVPNStateChanged.observe(call: #selector(reloadTabBarBadge), on: self)
		
		if !Prefs.DidShowTutorial.Welcome {
			self.perform(#selector(showWelcomeMessage), with: nil, afterDelay: 0.5)
		}
		if #available(iOS 10.0, *) {
			initNotifications()
		}
	}
	
	@objc private func reloadTabBarBadge() {
		let stateView = self.tabBar.items?.last
		switch GlassVPN.state {
		case .on:        stateView?.badgeValue = "✓"
		case .inbetween: stateView?.badgeValue = "⋯"
		case .off:       stateView?.badgeValue = "✗"
		}
		if #available(iOS 10.0, *) {
			switch GlassVPN.state {
			case .on:        stateView?.badgeColor = .systemGreen
			case .inbetween: stateView?.badgeColor = .systemYellow
			case .off:       stateView?.badgeColor = .systemRed
			}
		}
	}
	
	@objc private func showWelcomeMessage() {
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(TinyMarkdown.load("tut-welcome-1"))
		x.addSheet().addArrangedSubview(TinyMarkdown.load("tut-welcome-2"))
		x.present {
			Prefs.DidShowTutorial.Welcome = true
		}
	}
}

extension TBCMain {
	@discardableResult func openTab(_ index: Int) -> UIViewController? {
		selectedIndex = index
		guard let nav = selectedViewController as? UINavigationController else {
			return selectedViewController
		}
		nav.popToRootViewController(animated: false)
		return nav.topViewController
	}
}

// MARK: - Push Notifications

@available(iOS 10.0, *)
extension TBCMain: UNUserNotificationCenterDelegate {
	
	func initNotifications() {
		UNUserNotificationCenter.current().delegate = self
		guard Prefs.RecordingReminder.Enabled else {
			return
		}
		PushNotification.allowed {
			switch $0 {
			case .NotDetermined:
				PushNotification.requestProvisionalOrDoNothing { success in
					guard success else { return }
					PushNotification.scheduleRecordingReminder(force: false)
				}
			case .Denied:
				break
			case .Authorized, .Provisional:
				PushNotification.scheduleRecordingReminder(force: false)
			}
		}
	}
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.alert, .badge, .sound]) // in-app notifications
	}
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		defer { completionHandler() }
		if isFrontmostModal() {
			return // dont intervene user actions
		}
		switch response.notification.request.identifier {
		case PushNotification.Identifier.YouShallRecordMoreReminder.rawValue:
			selectedIndex = 1 // open recordings tab
		case PushNotification.Identifier.CantStopMeNowReminder.rawValue:
			(openTab(2) as! TVCSettings).openRestartVPNSettings()
		//case PushNotification.Identifier.RestInPeaceTombstoneReminder // only badge
		case let x: // domain notification
			(openTab(0) as! TVCDomains).pushOpen(domain: x) // open requests tab
		}
	}
	
	@available(iOS 12.0, *)
	func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
		(openTab(2) as! TVCSettings).openNotificationSettings()
	}
	
	func isFrontmostModal() -> Bool {
		var x = selectedViewController!
		while let tmp = x.presentedViewController {
			x = tmp
		}
		if x is UIAlertController {
			return true
		} else if #available(iOS 13.0, *) {
			return x.isModalInPresentation
		} else {
			return x.modalPresentationStyle == .custom
		}
	}
}
