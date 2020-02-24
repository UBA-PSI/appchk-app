import NetworkExtension
import NEKit

fileprivate var db: SQLiteDatabase?
fileprivate var blockedDomains: [String] = []
fileprivate var ignoredDomains: [String] = []

// MARK: ObserverFactory

class LDObserverFactory: ObserverFactory {
    
	override func getObserverForProxySocket(_ socket: ProxySocket) -> Observer<ProxySocketEvent>? {
		return LDProxySocketObserver()
	}
	
	class LDProxySocketObserver: Observer<ProxySocketEvent> {
		override func signal(_ event: ProxySocketEvent) {
			switch event {
			case .receivedRequest(let session, let socket):
				QLog("DNS: \(session.host)")
				if ignoredDomains.allSatisfy({ session.host != $0 && !session.host.hasSuffix("." + $0) }) {
					try? db?.insertDNSQuery(session.host)
				} else {
					QLog("ignored")
				}
				for domain in blockedDomains {
                    if (session.host == domain || session.host.hasSuffix("." + domain)) {
                        QLog("blocked")
						socket.forceDisconnect()
                        return
                    }
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
		QLog("startTunnel")
		ignoredDomains = ["signal.org", "whispersystems.org"]
		// TODO: init blocked & ignored
		do {
			db = try SQLiteDatabase.open(path: DB_PATH)
			try db!.createTable(table: DNSQuery.self)
		} catch {
			completionHandler(error)
			return
		}
		if proxyServer != nil {
            proxyServer.stop()
        }
        proxyServer = nil
        
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
				QLog("setTunnelNetworkSettings error: \(String(describing: error))")
				completionHandler(error)
				return
			}
			QLog("setTunnelNetworkSettings success \(self.packetFlow)")
			completionHandler(nil)
			
			self.proxyServer = GCDHTTPProxyServer(address: IPAddress(fromString: self.proxyServerAddress), port: Port(port: self.proxyServerPort))
            do {
                try self.proxyServer.start()
                completionHandler(nil)
            }
            catch let proxyError {
                QLog("Error starting proxy server \(proxyError)")
                completionHandler(proxyError)
            }
		}
    }
	
    
	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		QLog("stopTunnel")
		db = nil
		DNSServer.currentServer = nil
        RawSocketFactory.TunnelProvider = nil
        ObserverFactory.currentFactory = nil
        proxyServer.stop()
        proxyServer = nil
        QLog("error on stopping: \(reason)")
        completionHandler()
        exit(EXIT_SUCCESS)
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        QLog("handleAppMessage")
        if let handler = completionHandler {
            handler(messageData)
        }
    }
}

public func QLog(_ message: String) {
	NSLog("TUN: \(message)")
}
