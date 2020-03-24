import NetworkExtension

fileprivate var db: SQLiteDatabase?
fileprivate var domainFilters: [String : FilterOptions] = [:]

// MARK: ObserverFactory

class LDObserverFactory: ObserverFactory {
    
	override func getObserverForProxySocket(_ socket: ProxySocket) -> Observer<ProxySocketEvent>? {
		return LDProxySocketObserver()
	}
	
	class LDProxySocketObserver: Observer<ProxySocketEvent> {
		override func signal(_ event: ProxySocketEvent) {
			switch event {
			case .receivedRequest(let session, let socket):
				DDLogDebug("DNS: \(session.host)")
				let match = domainFilters.first { session.host == $0.key || session.host.hasSuffix("." + $0.key) }
				let block = match?.value.contains(.blocked) ?? false
				let ignore = match?.value.contains(.ignored) ?? false
				if !ignore { try? db?.insertDNSQuery(session.host, blocked: block) }
				else { DDLogDebug("ignored") }
				if block { DDLogDebug("blocked"); socket.forceDisconnect() }
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
	
	func reloadDomainFilter() {
		domainFilters = db?.loadFilters() ?? [:]
	}

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
		DDLogVerbose("startTunnel")
		do {
			db = try SQLiteDatabase.open()
			db!.initScheme()
		} catch {
			completionHandler(error)
			return
		}
		if proxyServer != nil {
            proxyServer.stop()
        }
        proxyServer = nil
        
		reloadDomainFilter()
		
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
			DDLogVerbose("setTunnelNetworkSettings success \(self.packetFlow)")
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
		db = nil
		DNSServer.currentServer = nil
        RawSocketFactory.TunnelProvider = nil
        ObserverFactory.currentFactory = nil
        proxyServer.stop()
        proxyServer = nil
        completionHandler()
        exit(EXIT_SUCCESS)
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        DDLogVerbose("handleAppMessage")
		reloadDomainFilter()
    }
}
