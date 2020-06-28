import NetworkExtension

fileprivate var filterDomains: [String]!
fileprivate var filterOptions: [(block: Bool, ignore: Bool)]!


// MARK: Backward DNS Binary Tree Lookup

fileprivate func reloadDomainFilter() {
	let tmp = AppDB?.loadFilters()?.map({
		(String($0.reversed()), $1)
	}).sorted(by: { $0.0 < $1.0 }) ?? []
	filterDomains = tmp.map { $0.0 }
	filterOptions = tmp.map { ($1.contains(.blocked), $1.contains(.ignored)) }
}

fileprivate func filterIndex(for domain: String) -> Int {
	let reverseDomain = String(domain.reversed())
	var lo = 0, hi = filterDomains.count - 1
	while lo <= hi {
		let mid = (lo + hi)/2
		if filterDomains[mid] < reverseDomain {
			lo = mid + 1
		} else if reverseDomain < filterDomains[mid] {
			hi = mid - 1
		} else {
			return mid
		}
	}
	if lo > 0, reverseDomain.hasPrefix(filterDomains[lo - 1] + ".") {
		return lo - 1
	}
	return -1
}

private let queue = DispatchQueue.init(label: "PSIGlassDNSQueue", qos: .userInteractive, target: .main)

private func logAsync(_ domain: String, blocked: Bool) {
	queue.async {
		do {
			try AppDB?.logWrite(domain, blocked: blocked)
		} catch {
			DDLogWarn("Couldn't write: \(error)")
		}
	}
}


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
				let i = filterIndex(for: session.host)
				if i >= 0 {
					let (block, ignore) = filterOptions[i]
					if !ignore { logAsync(session.host, blocked: block) }
					if block { socket.forceDisconnect() }
				} else {
					// TODO: disable filter during recordings
					logAsync(session.host, blocked: false)
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
	
	private var autoDeleteTimer: Timer? = nil
	
	private func reloadSettings() {
		reloadDomainFilter()
		setAutoDelete(PrefsShared.AutoDeleteLogsDays)
	}
	
	override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
		DDLogVerbose("startTunnel with with options: \(String(describing: options))")
		do {
			try SQLiteDatabase.open().initCommonScheme()
		} catch {
			completionHandler(error)
			return
		}
		reloadSettings()
		
		if proxyServer != nil {
			proxyServer.stop()
		}
		proxyServer = nil
		
		// Create proxy
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
		
		self.setTunnelNetworkSettings(settings) { error in
			guard error == nil else {
				DDLogError("setTunnelNetworkSettings error: \(String(describing: error))")
				completionHandler(error)
				return
			}
			completionHandler(nil)
			
			self.proxyServer = GCDHTTPProxyServer(address: IPAddress(fromString: self.proxyServerAddress), port: Port(port: self.proxyServerPort))
			do {
				try self.proxyServer.start()
				completionHandler(nil)
			}
			catch let proxyError {
				DDLogError("Error starting proxy server \(proxyError)")
				completionHandler(proxyError)
			}
		}
	}
	
	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		DDLogVerbose("stopTunnel with reason: \(reason)")
		DNSServer.currentServer = nil
		RawSocketFactory.TunnelProvider = nil
		ObserverFactory.currentFactory = nil
		proxyServer.stop()
		proxyServer = nil
		filterDomains = nil
		filterOptions = nil
		autoDeleteTimer?.fire() // one last time before we quit
		autoDeleteTimer?.invalidate()
		completionHandler()
		exit(EXIT_SUCCESS)
	}
	
	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		let message = String(data: messageData, encoding: .utf8)
		if let msg = message, let i = msg.firstIndex(of: ":") {
			let action = msg.prefix(upTo: i)
			let value = msg.suffix(from: msg.index(after: i))
			switch action {
			case "filter-update":
				reloadDomainFilter() // TODO: reload only selected domain?
				return
			case "auto-delete":
				setAutoDelete(Int(value) ?? PrefsShared.AutoDeleteLogsDays)
				return
			default: break
			}
		}
		DDLogWarn("This should never happen! Received unknown handleAppMessage: \(message ?? messageData.base64EncodedString())")
		reloadSettings() // just in case we fallback to do everything
	}
}


// ################################################################
// #
// #    MARK: - Auto-delete Timer
// #
// ################################################################

extension PacketTunnelProvider {
	
	private func setAutoDelete(_ days: Int) {
		autoDeleteTimer?.invalidate()
		guard days > 0 else { return }
		// Repeat interval uses days as hours. min 1 hr, max 24 hrs.
		let interval = TimeInterval(min(24, days) * 60 * 60)
		autoDeleteTimer = Timer.scheduledTimer(timeInterval: interval,
											   target: self, selector: #selector(autoDeleteNow),
											   userInfo: days, repeats: true)
		autoDeleteTimer!.fire()
	}
	
	@objc private func autoDeleteNow(_ sender: Timer) {
		DDLogInfo("Auto-delete old logs")
		queue.async {
			do {
				try AppDB?.dnsLogsDeleteOlderThan(days: sender.userInfo as! Int)
			} catch {
				DDLogWarn("Couldn't delete logs, will retry in 5 minutes. \(error)")
				if sender.isValid {
					sender.fireDate = Date().addingTimeInterval(300) // retry in 5 min
				}
			}
		}
	}
}
