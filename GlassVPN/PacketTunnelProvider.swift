import NetworkExtension

let connectMessage: Data = "CONNECT".data(using: .ascii)!
let swcdUserAgent: Data = "User-Agent: swcd".data(using: .ascii)!
fileprivate var hook : GlassVPNHook!

// MARK: ObserverFactory

class LDObserverFactory: ObserverFactory {
	
	override func getObserverForProxySocket(_ socket: ProxySocket) -> Observer<ProxySocketEvent>? {
		// TODO: replace NEKit with custom proxy with minimal footprint
		return LDProxySocketObserver()
	}
	
	class LDProxySocketObserver: Observer<ProxySocketEvent> {
		override func signal(_ event: ProxySocketEvent) {
			switch event {
			case .receivedRequest(let session, let socket):
				if socket.isCancelled ||
					(hook.forceDisconnectUnresolvable && session.ipAddress.isEmpty) {
					hook.silentlyPrevented(session.host)
					socket.forceDisconnect()
					return
				}
				let kill = hook.processDNSRequest(session.host)
				if kill { socket.forceDisconnect() }
			case .readData(let data, on: let socket):
				if hook.forceDisconnectSWCD,
					data.starts(with: connectMessage),
					data.range(of: swcdUserAgent) != nil {
					socket.disconnect()
				}
			default:
				break
			}
		}
	}
}


// MARK: NEPacketTunnelProvider

class PacketTunnelProvider: NEPacketTunnelProvider {
	
	private let proxyServerPort: UInt16 = 9090
	private let proxyServerAddress = "127.0.0.1"
	private var proxyServer: GCDHTTPProxyServer!
	
	// MARK: Delegate
	
	override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
		DDLogVerbose("startTunnel with with options: \(String(describing: options))")
		PrefsShared.registerDefaults()
		do {
			try SQLiteDatabase.open().initCommonScheme()
		} catch {
			completionHandler(error) // if we cant open db, fail immediately
			return
		}
		// stop previous if any
		if proxyServer != nil { proxyServer.stop() }
		proxyServer = nil
		
		willInitProxy()
		
		self.setTunnelNetworkSettings(createProxy()) { error in
			guard error == nil else {
				DDLogError("setTunnelNetworkSettings error: \(error!)")
				completionHandler(error)
				return
			}
			self.proxyServer = GCDHTTPProxyServer(address: IPAddress(fromString: self.proxyServerAddress), port: Port(port: self.proxyServerPort))
			do {
				try self.proxyServer.start()
				self.didInitProxy()
				completionHandler(nil)
			} catch let proxyError {
				DDLogError("Error starting proxy server \(proxyError)")
				completionHandler(proxyError)
			}
		}
	}
	
	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		DDLogVerbose("stopTunnel with reason: \(reason)")
		shutdown()
		completionHandler()
		exit(EXIT_SUCCESS)
	}
	
	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		hook.handleAppMessage(messageData)
	}
	
	// MARK: Helper
	
	private func willInitProxy() {
		hook = GlassVPNHook()
	}
	
	private func createProxy() -> NEPacketTunnelNetworkSettings {
		let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: proxyServerAddress)
		settings.mtu = NSNumber(value: 1500)
		
		let proxySettings = NEProxySettings()
		proxySettings.httpEnabled = true;
		proxySettings.httpServer = NEProxyServer(address: proxyServerAddress, port: Int(proxyServerPort))
		proxySettings.httpsEnabled = true;
		proxySettings.httpsServer = NEProxyServer(address: proxyServerAddress, port: Int(proxyServerPort))
		proxySettings.excludeSimpleHostnames = false;
		proxySettings.exceptionList = []
		proxySettings.matchDomains = [""]
		
		settings.dnsSettings = NEDNSSettings(servers: ["127.0.0.1"])
		settings.proxySettings = proxySettings;
		RawSocketFactory.TunnelProvider = self
		ObserverFactory.currentFactory = LDObserverFactory()
		return settings
	}
	
	private func didInitProxy() {
		if PrefsShared.RestartReminder.Enabled {
			PushNotification.scheduleRestartReminderBadge(on: false)
			PushNotification.cancel(.CantStopMeNowReminder)
		}
	}
	
	private func shutdown() {
		// proxy
		DNSServer.currentServer = nil
		RawSocketFactory.TunnelProvider = nil
		ObserverFactory.currentFactory = nil
		proxyServer.stop()
		proxyServer = nil
		// custom
		hook.cleanUp()
		hook = nil
		if PrefsShared.RestartReminder.Enabled {
			PushNotification.scheduleRestartReminderBadge(on: true)
			PushNotification.scheduleRestartReminderBanner()
		}
	}
}
