import UIKit
import NetworkExtension

class TBCMain: UITabBarController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		NotifyVPNStateChanged.observe(call: #selector(vpnStateChanged(_:)), on: self)
		changedState(currentVPNState)
		
		if !Pref.DidShowTutorial.Welcome {
			self.perform(#selector(showWelcomeMessage), with: nil, afterDelay: 0.5)
		}
	}
	
	@objc func showWelcomeMessage() {
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
			Pref.DidShowTutorial.Welcome = true
		}
	}
	
	@objc func vpnStateChanged(_ notification: Notification) {
		changedState(notification.object as! VPNState)
	}
	
	func changedState(_ newState: VPNState) {
		let stateView = self.tabBar.items?.last
		switch newState {
		case .on:        stateView?.badgeValue = "✓"
		case .inbetween: stateView?.badgeValue = "⋯"
		case .off:       stateView?.badgeValue = "✗"
		}
		if #available(iOS 10.0, *) {
			switch newState {
			case .on:        stateView?.badgeColor = .systemGreen
			case .inbetween: stateView?.badgeColor = .systemYellow
			case .off:       stateView?.badgeColor = .systemRed
			}
		}
	}
}
