import UIKit
import NetworkExtension

let VPNConfigBundleIdentifier = "de.uni-bamberg.psi.AppCheck.VPN"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	var managerVPN: NETunnelProviderManager?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		if UserDefaults.standard.bool(forKey: "kill_db") {
			UserDefaults.standard.set(false, forKey: "kill_db")
			SQLiteDatabase.destroyDatabase()
		}
		try? SQLiteDatabase.open().initScheme()
		
		DBWrp.initContentOfDB()
		
		loadVPN { mgr in
			self.managerVPN = mgr
			self.postVPNState()
		}
		NSNotification.Name.NEVPNStatusDidChange.observe(call: #selector(vpnStatusChanged(_:)), on: self)
		NotifyFilterChanged.observe(call: #selector(filterDidChange), on: self)
		return true
	}
	
	@objc private func vpnStatusChanged(_ notification: Notification) {
		postRawVPNState((notification.object as? NETunnelProviderSession)?.status ?? .invalid)
	}
	
	@objc private func filterDidChange() {
		// Notify VPN extension about changes
		if let session = self.managerVPN?.connection as? NETunnelProviderSession,
			session.status == .connected {
			try? session.sendProviderMessage("filter-update".data(using: .ascii)!, responseHandler: nil)
		}
	}
	
	func setProxyEnabled(_ newState: Bool) {
		guard let mgr = self.managerVPN else {
			self.createNewVPN { manager in
				self.managerVPN = manager
				self.setProxyEnabled(newState)
			}
			return
		}
		let state = mgr.isEnabled && (mgr.connection.status == .connected)
		if state != newState {
			self.updateVPN({ mgr.isEnabled = true }) {
				newState ? try? mgr.connection.startVPNTunnel() : mgr.connection.stopVPNTunnel()
			}
		}
	}
	
	// MARK: VPN
	
	private func createNewVPN(_ success: @escaping (_ manager: NETunnelProviderManager) -> Void) {
		let mgr = NETunnelProviderManager()
		mgr.localizedDescription = "AppCheck Monitor"
		let proto = NETunnelProviderProtocol()
		proto.providerBundleIdentifier = VPNConfigBundleIdentifier
		proto.serverAddress = "127.0.0.1"
		mgr.protocolConfiguration = proto
		mgr.isEnabled = true
		mgr.saveToPreferences { error in
			guard error == nil else {
				self.postProcessedVPNState(.off)
				//ErrorAlert(error!).presentIn(self.window?.rootViewController)
				return
			}
			success(mgr)
		}
	}
	
	private func loadVPN(_ finally: @escaping (_ manager: NETunnelProviderManager?) -> Void) {
		NETunnelProviderManager.loadAllFromPreferences { managers, error in
			guard let mgrs = managers, mgrs.count > 0 else {
				finally(nil)
				return
			}
			for mgr in mgrs {
				if let proto = (mgr.protocolConfiguration as? NETunnelProviderProtocol) {
					if proto.providerBundleIdentifier == VPNConfigBundleIdentifier {
						finally(mgr)
						return
					}
				}
			}
			finally(nil)
		}
	}
	
	private func updateVPN(_ body: @escaping () -> Void, _ onSuccess: @escaping () -> Void) {
		self.managerVPN?.loadFromPreferences { error in
			guard error == nil else { return }
			body()
			self.managerVPN?.saveToPreferences { error in
				guard error == nil else { return }
				onSuccess()
			}
		}
	}
	
	private func postVPNState() {
		guard let mgr = self.managerVPN else {
			self.postRawVPNState(.invalid)
			return
		}
		mgr.loadFromPreferences { _ in
			self.postRawVPNState(mgr.connection.status)
		}
	}
	
	// MARK: Notifications
	
	private func postRawVPNState(_ origState: NEVPNStatus) {
		let state: VPNState
		switch origState {
		case .connected: 								state = .on
		case .connecting, .disconnecting, .reasserting: state = .inbetween
		case .invalid, .disconnected: fallthrough
		@unknown default: 								state = .off
		}
		postProcessedVPNState(state)
	}
	
	private func postProcessedVPNState(_ state: VPNState) {
		currentVPNState = state
		NotifyVPNStateChanged.post(state)
	}
}
