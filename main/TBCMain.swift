import UIKit
import NetworkExtension

class TBCMain: UITabBarController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
//		perform(#selector(showWelcomeMessage), with: nil, afterDelay: 3)
		NotifyVPNStateChanged.observe(call: #selector(vpnStateChanged(_:)), on: self)
		changedState(currentVPNState)
	}
	
	@objc func showWelcomeMessage() {
		performSegue(withIdentifier: "welcome", sender: nil)
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
