import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
		NSLog("TUN: startTunnel")
//		let endpoint = NWHostEndpoint(hostname:"127.0.0.1", port:"4000")
//		self.createTCPConnection(to: endpoint, enableTLS: false, tlsParameters: nil, delegate: nil)
		completionHandler(nil)
		/*
		let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
		let ip4set = NEIPv4Settings(addresses: ["127.0.0.1"], subnetMasks: ["255.255.255.0"])
		let defaultRoute = NEIPv4Route.default()
		let localRoute = NEIPv4Route(destinationAddress: "192.168.2.1", subnetMask: "255.255.255.0")
		ip4set.includedRoutes = [defaultRoute, localRoute]
		ip4set.excludedRoutes = []
		settings.ipv4Settings = ip4set
//		settings.mtu = 1500
		settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
		settings.tunnelOverheadBytes = 150
		
		self.setTunnelNetworkSettings(settings) { error in
			guard error == nil else {
				NSLog("setTunnelNetworkSettings error: \(String(describing: error))")
				return
			}
			NSLog("setTunnelNetworkSettings success")
			completionHandler(nil)
		}*/
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("TUN: stopTunnel")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        NSLog("TUN: handleAppMessage")
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        NSLog("TUN: sleep")
        completionHandler()
    }
    
    override func wake() {
        NSLog("TUN: wake")
    }
	
	override func createUDPSessionThroughTunnel(to remoteEndpoint: NWEndpoint, from localEndpoint: NWHostEndpoint?) -> NWUDPSession {
		NSLog("TUN: createUDP")
		return createUDPSession(to: remoteEndpoint, from: localEndpoint)
	}
}
