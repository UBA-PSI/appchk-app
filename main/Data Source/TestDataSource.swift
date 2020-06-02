import Foundation

#if IOS_SIMULATOR

private let db = AppDB!
private var pStmt: OpaquePointer?

class TestDataSource {
	
	static func load() {
		QLog.Debug("SQLite path: \(URL.internalDB())")
		
		let deleted = db.dnsLogsDelete("test.com", strict: false)
		QLog.Debug("Deleting \(deleted) rows matching 'test.com'")
		
		QLog.Debug("Writing 33 test logs")
		pStmt = try! db.logWritePrepare()
		try? db.logWrite(pStmt, "keeptest.com", blocked: false)
		for _ in 1...4 { try? db.logWrite(pStmt, "test.com", blocked: false) }
		for _ in 1...7 { try? db.logWrite(pStmt, "i.test.com", blocked: false) }
		for i in 1...8 { try? db.logWrite(pStmt, "b.test.com", blocked: i>5) }
		for i in 1...13 { try? db.logWrite(pStmt, "bi.test.com", blocked: i%2==0) }
		
		db.dnsLogsPersist()
		
		QLog.Debug("Creating 4 filters")
		db.setFilter("b.test.com", .blocked)
		db.setFilter("i.test.com", .ignored)
		db.setFilter("bi.test.com", [.blocked, .ignored])
		
		QLog.Debug("Done")
		
		Timer.repeating(2, call: #selector(insertRandom), on: self)
	}
	
	@objc static func insertRandom() {
		//QLog.Debug("Inserting 1 periodic log entry")
		try? db.logWrite(pStmt, "\(arc4random() % 5).count.test.com", blocked: true)
	}
}
#endif
