import UIKit
import NetworkExtension

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		
		if UserDefaults.standard.bool(forKey: "kill_proxy") {
			UserDefaults.standard.set(false, forKey: "kill_proxy")
			disableDNS()
		} else {
			postDNSState()
		}
		
		if UserDefaults.standard.bool(forKey: "kill_db") {
			UserDefaults.standard.set(false, forKey: "kill_db")
			SQLiteDatabase.destroyDatabase(path: DB_PATH)
		}
		do {
			let db = try SQLiteDatabase.open(path: DB_PATH)
			try db.createTable(table: DNSQuery.self)
		} catch {}
		
//		loadVPN { self.startVPN() }
		return true
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
		postDNSState()
	}
	
	func setProxyEnabled(_ newState: Bool) {
		// DNS:
		if newState != managerDNS.isEnabled {
			newState ? enableDNS() : disableDNS()
		}
		// VPN:
//		let con = self.managerVPN?.connection
//		if newState != (con?.status == NEVPNStatus.connected) {
//			self.updateVPN {
//				self.managerVPN?.isEnabled = newState
//				newState ? try? con?.startVPNTunnel() : con?.stopVPNTunnel()
//			}
//		}
	}
	
	
	// MARK: DNS
	
	let managerDNS = NEDNSProxyManager.shared()

	private func enableDNS() {
		updateDNS {
			self.managerDNS.localizedDescription = "GlassDNS"
			let proto = NEDNSProxyProviderProtocol()
			proto.providerBundleIdentifier = "de.uni-bamberg.psi.AppCheck.DNS"
			self.managerDNS.providerProtocol = proto
			self.managerDNS.isEnabled = true
		}
	}
	
	private func disableDNS() {
		updateDNS {
			self.managerDNS.isEnabled = false
		}
	}
	
	private func updateDNS(_ body: @escaping () -> Void) {
		managerDNS.loadFromPreferences { (error) in
			guard error == nil else { return }
			body()
			self.managerDNS.saveToPreferences { (error) in
				self.postDNSState()
				guard error == nil else { return }
			}
		}
	}
	
	private func postDNSState() {
		managerDNS.loadFromPreferences {_ in
			NotificationCenter.default.post(name: .init("ChangedStateGlassDNS"), object: self.managerDNS.isEnabled)
		}
	}
	
	
	// MARK: VPN
	
	/*var managerVPN: NETunnelProviderManager?
	
	private func loadVPN(_ finally: @escaping () -> Void) {
		NETunnelProviderManager.loadAllFromPreferences { managers, error in
			if managers?.count ?? 0 > 0 {
				managers?.forEach({ mgr in
					if let proto = (mgr.protocolConfiguration as? NETunnelProviderProtocol) {
						if proto.providerBundleIdentifier == "de.uni-bamberg.psi.AppCheck.Tunnel" {
//							self.managerVPN = mgr
							mgr.removeFromPreferences()
						}
					}
				})
			}
			if self.managerVPN != nil {
				finally()
			} else {
				let mgr = NETunnelProviderManager()
				mgr.localizedDescription = "GlassTunnel"
				let proto = NETunnelProviderProtocol()
				proto.providerBundleIdentifier = "de.uni-bamberg.psi.AppCheck.Tunnel"
				proto.serverAddress = "127.0.0.1"
//				proto.username = "none"
//				proto.proxySettings = NEProxySettings()
//				proto.proxySettings?.httpEnabled = true
//				proto.proxySettings?.httpsEnabled = true
//				proto.authenticationMethod = .sharedSecret
//				proto.sharedSecretReference = try! VPNKeychain.persistentReferenceFor(service: "GlassTunnel", account:"none", password: "none".data(using: String.Encoding.utf8)!)
				mgr.protocolConfiguration = proto
				mgr.isEnabled = true
				self.managerVPN = mgr
				mgr.saveToPreferences { (error) in
					guard error == nil else {
						NSLog("VPN: save error: \(String(describing: error))")
						return
					}
					finally()
				}
			}
		}
	}
	
	private func startVPN() {
		updateVPN {
			do {
				try self.managerVPN?.connection.startVPNTunnel()
			} catch {
				print("VPN: start error: \(error.localizedDescription)")
			}
		}
	}
	
	private func updateVPN(_ body: @escaping () -> Void) {
		self.managerVPN?.loadFromPreferences { (error) in
			guard error == nil else {
				return
			}
			body()
			self.managerVPN?.saveToPreferences { (error) in
				guard error == nil else {
					NSLog("VPN: save error: \(String(describing: error))")
					return
				}
			}
		}
	}*/
}

// MARK: VPNKeychain
/*
/// Utility routines for working with the keychain.

enum VPNKeychain {
	/// Returns a persistent reference for a generic password keychain item, adding it to
	/// (or updating it in) the keychain if necessary.
	///
	/// This delegates the work to two helper routines depending on whether the item already
	/// exists in the keychain or not.
	///
	/// - Parameters:
	///   - service: The service name for the item.
	///   - account: The account for the item.
	///   - password: The desired password.
	/// - Returns: A persistent reference to the item.
	/// - Throws: Any error returned by the Security framework.
	
	static func persistentReferenceFor(service: String, account: String, password: Data) throws -> Data {
		var copyResult: CFTypeRef? = nil
		let err = SecItemCopyMatching([
			kSecClass: kSecClassGenericPassword,
			kSecAttrService: service,
			kSecAttrAccount: account,
			kSecReturnPersistentRef: true,
			kSecReturnData: true
			] as NSDictionary, &copyResult)
		switch err {
		case errSecSuccess:
			return try self.persistentReferenceByUpdating(copyResult: copyResult!, service: service, account: account, password: password)
		case errSecItemNotFound:
			return try self.persistentReferenceByAdding(service: service, account:account, password: password)
		default:
			try throwOSStatus(err)
			// `throwOSStatus(_:)` only returns in the `errSecSuccess` case.  We know we're
			// not in that case but the compiler can't figure that out, alas.
			fatalError()
		}
	}
	
	/// Returns a persistent reference for a generic password keychain item by updating it
	/// in the keychain if necessary.
	///
	/// - Parameters:
	///   - copyResult: The result from the `SecItemCopyMatching` done by `persistentReferenceFor(service:account:password:)`.
	///   - service: The service name for the item.
	///   - account: The account for the item.
	///   - password: The desired password.
	/// - Returns: A persistent reference to the item.
	/// - Throws: Any error returned by the Security framework.
	
	private static func persistentReferenceByUpdating(copyResult: CFTypeRef, service: String, account: String, password: Data) throws -> Data {
		let copyResult = copyResult as! [String:Any]
		let persistentRef = copyResult[kSecValuePersistentRef as String] as! NSData as Data
		let currentPassword = copyResult[kSecValueData as String] as! NSData as Data
		if password != currentPassword {
			let err = SecItemUpdate([
				kSecClass: kSecClassGenericPassword,
				kSecAttrService: service,
				kSecAttrAccount: account,
				] as NSDictionary, [
					kSecValueData: password
					] as NSDictionary)
			try throwOSStatus(err)
		}
		return persistentRef
	}
	
	/// Returns a persistent reference for a generic password keychain item by adding it to
	/// the keychain.
	///
	/// - Parameters:
	///   - service: The service name for the item.
	///   - account: The account for the item.
	///   - password: The desired password.
	/// - Returns: A persistent reference to the item.
	/// - Throws: Any error returned by the Security framework.
	
	private static func persistentReferenceByAdding(service: String, account: String, password: Data) throws -> Data {
		var addResult: CFTypeRef? = nil
		let err = SecItemAdd([
			kSecClass: kSecClassGenericPassword,
			kSecAttrService: service,
			kSecAttrAccount: account,
			kSecValueData: password,
			kSecReturnPersistentRef: true,
			] as NSDictionary, &addResult)
		try throwOSStatus(err)
		return addResult! as! NSData as Data
	}
	
	/// Throws an error if a Security framework call has failed.
	///
	/// - Parameter err: The error to check.
	
	private static func throwOSStatus(_ err: OSStatus) throws {
		guard err == errSecSuccess else {
			throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
		}
	}
}
*/
