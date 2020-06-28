import NetworkExtension

let GlassVPN = GlassVPNManager()

enum VPNState : Int { case on = 1, inbetween, off }

final class GlassVPNManager {
	static let bundleIdentifier = "de.uni-bamberg.psi.AppCheck.VPN"
	private var managerVPN: NETunnelProviderManager?
	private(set) var state: VPNState = .off
	
	fileprivate init() {
		NETunnelProviderManager.loadAllFromPreferences { managers, error in
			self.managerVPN = managers?.first {
				($0.protocolConfiguration as? NETunnelProviderProtocol)?
					.providerBundleIdentifier == GlassVPNManager.bundleIdentifier
			}
			guard let mgr = self.managerVPN else {
				self.postRawVPNState(.invalid)
				return
			}
			mgr.loadFromPreferences { _ in
				self.postRawVPNState(mgr.connection.status)
			}
		}
		NSNotification.Name.NEVPNStatusDidChange.observe(call: #selector(vpnStatusChanged(_:)), on: self)
		NotifyDNSFilterChanged.observe(call: #selector(didChangeDomainFilter), on: self)
	}
	
	func setEnabled(_ newState: Bool) {
		guard let mgr = self.managerVPN else {
			self.createNewVPN { manager in
				self.managerVPN = manager
				self.setEnabled(newState)
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
	
	
	// MARK: - Notify callback
	
	@objc private func vpnStatusChanged(_ notification: Notification) {
		postRawVPNState((notification.object as? NETunnelProviderSession)?.status ?? .invalid)
	}
	
	@objc private func didChangeDomainFilter() {
		// Notify VPN extension about changes
		if let session = self.managerVPN?.connection as? NETunnelProviderSession,
			session.status == .connected {
			try? session.sendProviderMessage("filter-update".data(using: .ascii)!, responseHandler: nil)
		}
	}
	
	
	// MARK: - Manage configuration
	
	private func createNewVPN(_ success: @escaping (_ manager: NETunnelProviderManager) -> Void) {
		let mgr = NETunnelProviderManager()
		mgr.localizedDescription = "AppCheck Monitor"
		let proto = NETunnelProviderProtocol()
		proto.providerBundleIdentifier = GlassVPNManager.bundleIdentifier
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
	
	
	// MARK: - Post Notifications
	
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
		self.state = state
		NotifyVPNStateChanged.post(state)
	}
}
