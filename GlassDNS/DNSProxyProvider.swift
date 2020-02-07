import NetworkExtension
import DNS

fileprivate var db: SQLiteDatabase?

class DNSProxyProvider: NEDNSProxyProvider {
	
	override func startProxy(options:[String: Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
		// Add code here to start the DNS proxy.
		simpleTunnelLog("startProxy")
		do {
			db = try SQLiteDatabase.open(path: DB_PATH)
			try db!.createTable(table: DNSQuery.self)
		} catch {
			simpleTunnelLog("Error: \(error)")
			completionHandler(error)
			return
		}
		completionHandler(nil)
	}
	
	override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		// Add code here to stop the DNS proxy.
		simpleTunnelLog("stopProxy")
		db = nil
		completionHandler()
	}
	
	override func sleep(completionHandler: @escaping () -> Void) {
		// Add code here to get ready to sleep.
		simpleTunnelLog("sleep")
		completionHandler()
	}
	
	override func wake() {
		// Add code here to wake up.
		simpleTunnelLog("wake")
	}
	
	override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
		simpleTunnelLog("handleUDPFlow \(flow.metaData.sourceAppSigningIdentifier)")
		simpleTunnelLog("handleUDPFlow \((remoteEndpoint as! NWHostEndpoint).hostname)")
		
		let con = createUDPSession(to: remoteEndpoint, from: (flow.localEndpoint as! NWHostEndpoint))
		let newConnection = ClientDNSProxy(newUDPFlow: flow)
		newConnection.open(con)
		return true
	}
	
	
	/*override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
	// Add code here to handle the incoming flow.
	NSLog("PSI: handleFlow %@", flow.metaData.sourceAppSigningIdentifier)
	
	var newConnection: ClientAppProxyConnection?
	
	guard let clientTunnel = tunnel else { return false }
	
	
	if let tcpFlow = flow as? NEAppProxyTCPFlow {
	let remoteHost = (tcpFlow.remoteEndpoint as! NWHostEndpoint).hostname
	let remotePort = (tcpFlow.remoteEndpoint as! NWHostEndpoint).port
	NSLog("PSI: TCP HOST : \(remoteHost)")
	NSLog("PSI: TCP PORT : \(remotePort)")
	newConnection = ClientAppProxyTCPConnection(tunnel: clientTunnel, newTCPFlow: tcpFlow)
	} else if let udpFlow = flow as? NEAppProxyUDPFlow {
	let localHost = (udpFlow.localEndpoint as! NWHostEndpoint).hostname
	let localPort = (udpFlow.localEndpoint as! NWHostEndpoint).port
	NSLog("PSI: UDP HOST : \(localHost)")
	NSLog("PSI: UDP PORT : \(localPort)")
	newConnection = ClientAppProxyUDPConnection(tunnel: clientTunnel, newUDPFlow: udpFlow)
	}
	
	guard newConnection != nil else { return false }
	
	newConnection!.open()
	
	return true
	//		return super.handleNewFlow(flow)
	}*/
}

class ClientDNSProxy : NSObject {
	public let identifier: Int
	let appProxyFlow: NEAppProxyFlow
	var datagramsOutstanding = 0
	var conn: NWUDPSession?
	
	/// The NEAppProxyUDPFlow object corresponding to this connection.
	var UDPFlow: NEAppProxyUDPFlow {
		return (appProxyFlow as! NEAppProxyUDPFlow)
	}
	
	init(newUDPFlow: NEAppProxyUDPFlow) {
		appProxyFlow = newUDPFlow
		identifier = newUDPFlow.hash
		super.init()
	}
	
	/// Send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol.
	func open(_ connection: NWUDPSession) {
//		open([
//				TunnelMessageKey.TunnelType.rawValue: TunnelLayer.app.rawValue as AnyObject,
//				TunnelMessageKey.AppProxyFlowType.rawValue: AppProxyFlowKind.udp.rawValue as AnyObject
//			])
		connection.setReadHandler({ datas, error in
			guard let datagrams = datas, error == nil else {
				simpleTunnelLog("Failed to read UDP connection: \(String(describing: error))")
				return
			}
			
			self.UDPFlow.writeDatagrams(datagrams, sentBy: [connection.endpoint]) { error in
				if let error = error {
					simpleTunnelLog("Failed to write datagrams to the UDP Flow: \(error)")
//					self.tunnel?.sendCloseType(.read, forConnection: self.identifier)
					self.UDPFlow.closeWriteWithError(nil)
				}
			}
		}, maxDatagrams: 32)
		self.conn = connection
		UDPFlow.open(withLocalEndpoint: (UDPFlow.localEndpoint as! NWHostEndpoint)) { (e: Error?) in
			self.handleSendResult(nil)
		}
	}
	
	/// Handle the result of sending a "Data" message to the SimpleTunnel server.
	func handleSendResult(_ error: NSError?) {
		
		if let sendError = error {
			simpleTunnelLog("Failed to send message to Tunnel Server. error = \(sendError)")
//			handleErrorCondition(.hostUnreachable)
			return
		}
		
		if datagramsOutstanding > 0 {
			datagramsOutstanding -= 1
		}
		
		// Only read more datagrams from the source application if all outstanding datagrams have been sent on the network.
		guard datagramsOutstanding == 0 else { return }
		
		// Read a new set of datagrams from the source application.
		UDPFlow.readDatagrams { datagrams, remoteEndPoints, readError in
			
			guard let readDatagrams = datagrams,
				let readEndpoints = remoteEndPoints
				, readError == nil else
			{
				simpleTunnelLog("Failed to read data from the UDP flow. error = \(String(describing: readError))")
//				self.handleErrorCondition(.peerReset)
				return
			}
			
			guard !readDatagrams.isEmpty && readEndpoints.count == readDatagrams.count else {
				simpleTunnelLog("\(self.identifier): Received EOF on the UDP flow. Closing the flow...")
//				self.tunnel?.sendCloseType(.write, forConnection: self.identifier)
				self.UDPFlow.closeReadWithError(nil)
				return
			}
			
			self.datagramsOutstanding = readDatagrams.count
			
			for (index, datagram) in readDatagrams.enumerated() {
				guard let endpoint = readEndpoints[index] as? NWHostEndpoint else { continue }
				
				let response = try! Message.init(deserialize: datagram)
				for q in response.questions {
					simpleTunnelLog("got name \(q.name)")
					try? db?.insertDNSQuery(appId: self.UDPFlow.metaData.sourceAppSigningIdentifier as NSString,
											dnsQuery: q.name as NSString)
				}
				
				simpleTunnelLog("(\(self.identifier)): Sending a \(datagram.count)-byte datagram to \(endpoint.hostname):\(endpoint.port)")
				// Send a data message to the SimpleTunnel server.
//				self.sendDataMessage(datagram, extraProperties:[
//						TunnelMessageKey.Host.rawValue: endpoint.hostname as AnyObject,
//						TunnelMessageKey.Port.rawValue: Int(endpoint.port)! as AnyObject
//					])
				self.conn?.writeDatagram(datagram, completionHandler: { conError in
					simpleTunnelLog("write con err: \(String(describing: conError))")
				})
			}
			
//			self.UDPFlow.writeDatagrams(readDatagrams, sentBy: readEndpoints) { writeError in
//				simpleTunnelLog("write error \(String(describing: writeError))")
//			}
		}
	}
	
	/// Send a datagram received from the SimpleTunnel server to the destination application.
	func sendDataWithEndPoint(_ data: Data, host: String, port: Int) {
		let datagrams = [ data ]
		let endpoints = [ NWHostEndpoint(hostname: host, port: String(port)) ]
		
		// Send the datagram to the destination application.
		UDPFlow.writeDatagrams(datagrams, sentBy: endpoints) { error in
			if let error = error {
				simpleTunnelLog("Failed to write datagrams to the UDP Flow: \(error)")
//				self.tunnel?.sendCloseType(.read, forConnection: self.identifier)
				self.UDPFlow.closeWriteWithError(nil)
			}
		}
	}
}


public func simpleTunnelLog(_ message: String) {
//	NSLog("PSI: \(message)")
}

