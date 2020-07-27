import Foundation

#if IOS_SIMULATOR

fileprivate var hook : GlassVPNHook!

class SimulatorVPN {
	static var timer: Timer?
	
	static func load() {
		QLog.Debug("SQLite path: \(URL.internalDB())")
		
		let db = AppDB!
		let deleted = db.dnsLogsDelete("test.com", strict: false)
		try? db.run(sql: "DELETE FROM cache;")
		QLog.Debug("Deleting \(deleted) rows matching 'test.com' (+ \(db.numberOfChanges) in cache)")
		
		QLog.Debug("Writing 33 test logs")
		try? db.logWrite("keeptest.com", blocked: false)
		for _ in 1...4 { try? db.logWrite("test.com", blocked: false) }
		for _ in 1...7 { try? db.logWrite("i.test.com", blocked: false) }
		for i in 1...8 { try? db.logWrite("b.test.com", blocked: i>5) }
		for i in 1...13 { try? db.logWrite("bi.test.com", blocked: i%2==0) }
		
		db.dnsLogsPersist()
		
		QLog.Debug("Creating 4 filters")
		db.setFilter("b.test.com", .blocked)
		db.setFilter("i.test.com", .ignored)
		db.setFilter("bi.test.com", [.blocked, .ignored])
		
		QLog.Debug("Done")
	}
	
	static func start() {
		hook = GlassVPNHook()
		timer = Timer.repeating(2, call: #selector(insertRandom), on: self)
	}
	
	static func stop() {
		timer?.invalidate()
		timer = nil
		hook.cleanUp()
		hook = nil
	}
	
	@objc static func insertRandom() {
		//QLog.Debug("Inserting 1 periodic log entry")
		let domain = "\(arc4random() % 5).count.test.com"
		let kill = hook.processDNSRequest(domain)
		if kill { QLog.Info("Blocked: \(domain)") }
	}
	
	static func sendMsg(_ messageData: Data) {
		hook.handleAppMessage(messageData)
	}
}
#endif
