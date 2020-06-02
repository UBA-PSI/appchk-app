import NetworkExtension

fileprivate var db: SQLiteDatabase!
fileprivate var pStmt: OpaquePointer!
fileprivate var filterDomains: [String]!
fileprivate var filterOptions: [(block: Bool, ignore: Bool)]!


// MARK: Backward DNS Binary Tree Lookup

fileprivate func reloadDomainFilter() {
	let tmp = db.loadFilters()?.map({
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
					if !ignore { try? db.logWrite(pStmt, session.host, blocked: block) }
					if block { socket.forceDisconnect() }
				} else {
					// TODO: disable filter during recordings
					try? db.logWrite(pStmt, session.host)
				}
			default:
				break
			}
		}
	}
}


// MARK: NEPacketTunnelProvider

class PacketTunnelProvider: NEPacketTunnelProvider {
	
	let proxyServerPort: UInt16 = 9090
	let proxyServerAddress = "127.0.0.1"
	var proxyServer: GCDHTTPProxyServer!
	
	override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
		do {
			db = try SQLiteDatabase.open()
			db.initCommonScheme()
			pStmt = try db.logWritePrepare()
		} catch {
			completionHandler(error)
			return
		}
		reloadDomainFilter()
		
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
		db.prepared(finalize: pStmt)
		pStmt = nil
		db = nil
		filterDomains = nil
		filterOptions = nil
		completionHandler()
		exit(EXIT_SUCCESS)
	}
	
	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		reloadDomainFilter()
	}
}

