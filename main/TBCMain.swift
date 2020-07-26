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
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("Welcome\n")
			.normal("\nAppCheck helps you identify which applications communicate with third parties. " +
				"It does so by logging network requests. " +
				"AppCheck learns only the destination addresses, not the actual data that is exchanged." +
				"\n\n" +
				"Your data belongs to you. " +
				"Therefore, monitoring and analysis take place on your device only. " +
				"The app does not share any data with us or any other third-party. " +
				"Unless you choose to.")
		))
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("How it works\n")
			.normal("\nAppCheck creates a local VPN tunnel to intercept all network connections. " +
				"For each connection AppCheck looks into the DNS headers only, namely the domain names. " +
				"\n" +
				"These domain names are logged in the background while the VPN is active. " +
				"That means, AppCheck does not have to be active in the foreground. " +
				"You can close the app and come back later to see the results."
			)
		))
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
		switch response.notification.request.identifier {
		case PushNotification.Identifier.YouShallRecordMoreReminder.rawValue:
			selectedIndex = 1 // open recordings tab
		case PushNotification.Identifier.CantStopMeNowReminder.rawValue:
			(openTab(2) as! TVCSettings).openRestartVPNSettings()
		//case PushNotification.Identifier.RestInPeaceTombstoneReminder // only badge
		default: // domain notification
			// TODO: open specific domain?
			openTab(0) // open Requests tab
		}
		completionHandler()
	}
	
	@available(iOS 12.0, *)
	func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
		(openTab(2) as! TVCSettings).openNotificationSettings()
	}
}
