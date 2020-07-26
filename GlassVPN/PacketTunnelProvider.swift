import NetworkExtension
import UserNotifications

private let queue = DispatchQueue.init(label: "PSIGlassDNSQueue", qos: .userInteractive, target: .main)

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
				let (block, ignore, cA, cB) = (i<0) ? (false, false, false, false) : filterOptions[i]
				let kill = ignore ? block : procRequest(session.host, blck: block, custA: cA, custB: cB)
				// TODO: disable ignore & block during recordings
				if kill { socket.forceDisconnect() }
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
			case "notify-prefs-change":
				reloadNotificationSettings()
				return
			default: break
			}
		}
		DDLogWarn("This should never happen! Received unknown handleAppMessage: \(message ?? messageData.base64EncodedString())")
		reloadSettings() // just in case we fallback to do everything
	}
	
	// MARK: Helper
	
	private func willInitProxy() {
		reloadSettings()
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
		filterDomains = nil
		filterOptions = nil
		autoDeleteTimer?.fire() // one last time before we quit
		autoDeleteTimer?.invalidate()
		notifyTone = nil
		if PrefsShared.RestartReminder.Enabled {
			PushNotification.scheduleRestartReminderBadge(on: true)
			PushNotification.scheduleRestartReminderBanner()
		}
	}
	
	private func reloadSettings() {
		reloadDomainFilter()
		setAutoDelete(PrefsShared.AutoDeleteLogsDays)
		reloadNotificationSettings()
	}
}


// ################################################################
// #
// #    MARK: - Domain Filter
// #
// ################################################################

fileprivate var filterDomains: [String]!
fileprivate var filterOptions: [(block: Bool, ignore: Bool, customA: Bool, customB: Bool)]!

extension PacketTunnelProvider {
	fileprivate func reloadDomainFilter() {
		let tmp = AppDB?.loadFilters()?.map({
			(String($0.reversed()), $1)
		}).sorted(by: { $0.0 < $1.0 }) ?? []
		let t1 = tmp.map { $0.0 }
		let t2 = tmp.map { ($1.contains(.blocked),
							$1.contains(.ignored),
							$1.contains(.customA),
							$1.contains(.customB)) }
		filterDomains = t1
		filterOptions = t2
	}
}

/// Backward DNS Binary Tree Lookup
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


// ################################################################
// #
// #    MARK: - Notifications
// #
// ################################################################

fileprivate var notifyEnabled: Bool = false
fileprivate var notifyIvertMode: Bool = false
fileprivate var notifyListBlocked: Bool = false
fileprivate var notifyListCustomA: Bool = false
fileprivate var notifyListCustomB: Bool = false
fileprivate var notifyListElse: Bool = false
fileprivate var notifyTone: AnyObject?

extension PacketTunnelProvider {
	func reloadNotificationSettings() {
		notifyEnabled = PrefsShared.ConnectionAlerts.Enabled
		guard #available(iOS 10.0, *), notifyEnabled else {
			notifyTone = nil
			return
		}
		notifyIvertMode = PrefsShared.ConnectionAlerts.ExcludeMode
		notifyListBlocked = PrefsShared.ConnectionAlerts.Lists.Blocked
		notifyListCustomA = PrefsShared.ConnectionAlerts.Lists.CustomA
		notifyListCustomB = PrefsShared.ConnectionAlerts.Lists.CustomB
		notifyListElse = PrefsShared.ConnectionAlerts.Lists.Else
		notifyTone = UNNotificationSound.from(string: PrefsShared.ConnectionAlerts.Sound)
	}
}


// ################################################################
// #
// #    MARK: - Process DNS Request
// #
// ################################################################

/// Log domain request and post notification if wanted.
/// - Returns: `true` if the request shoud be blocked
fileprivate func procRequest(_ domain: String, blck: Bool, custA: Bool, custB: Bool) -> Bool {
	queue.async {
		do { try AppDB?.logWrite(domain, blocked: blck) }
		catch { DDLogWarn("Couldn't write: \(error)") }
	}
	if #available(iOS 10.0, *), notifyEnabled {
		let onAnyList = notifyListBlocked && blck || notifyListCustomA && custA || notifyListCustomB && custB || notifyListElse
		if notifyIvertMode ? !onAnyList : onAnyList {
			// TODO: wait for response to block or allow connection
			PushNotification.scheduleConnectionAlert(domain, sound: notifyTone as! UNNotificationSound?)
		}
	}
	return blck
}
