import UIKit
import NetworkExtension

let VPNConfigBundleIdentifier = "de.uni-bamberg.psi.AppCheck.VPN"
let dateFormatter = DateFormatter()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	var managerVPN: NETunnelProviderManager?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		dateFormatter.dateFormat = "yyyy-MM-dd  HH:mm:ss"
		
//		if UserDefaults.standard.bool(forKey: "kill_proxy") {
//			UserDefaults.standard.set(false, forKey: "kill_proxy")
//			disableDNS()
//		} else {
//			postDNSState()
//		}
		
		if UserDefaults.standard.bool(forKey: "kill_db") {
			UserDefaults.standard.set(false, forKey: "kill_db")
			SQLiteDatabase.destroyDatabase(path: DB_PATH)
		}
		do {
			let db = try SQLiteDatabase.open(path: DB_PATH)
			try db.createTable(table: DNSQuery.self)
		} catch {}
		
		self.postVPNState(.invalid)
		loadVPN { mgr in
			self.managerVPN = mgr
			self.postVPNState()
		}
		return true
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//		postVPNState()
	}
	
	func setProxyEnabled(_ newState: Bool) {
		guard let mgr = self.managerVPN else {
			self.createNewVPN { manager in
				self.managerVPN = manager
				self.setProxyEnabled(newState)
			}
			return
		}
		let state = mgr.isEnabled && (mgr.connection.status == NEVPNStatus.connected)
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
			guard error == nil else { return }
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
			self.postVPNState(.invalid)
			return
		}
		mgr.loadFromPreferences { _ in
			self.postVPNState(mgr.connection.status)
		}
	}
	
	private func postVPNState(_ state: NEVPNStatus) {
		NotificationCenter.default.post(name: .init("ChangedStateGlassVPN"), object: state)
	}
}

