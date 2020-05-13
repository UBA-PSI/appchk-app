import Foundation
import SQLite3

typealias Timestamp = Int64

struct FilterOptions: OptionSet {
    let rawValue: Int32
	static let none    = FilterOptions([])
    static let blocked = FilterOptions(rawValue: 1 << 0)
    static let ignored = FilterOptions(rawValue: 1 << 1)
	static let any     = FilterOptions(rawValue: 0b11)
}

enum SQLiteError: Error {
	case OpenDatabase(message: String)
	case Prepare(message: String)
	case Step(message: String)
	case Bind(message: String)
}


// MARK: - SQLiteDatabase

class SQLiteDatabase {
	private let dbPointer: OpaquePointer?
	private init(dbPointer: OpaquePointer?) {
		self.dbPointer = dbPointer
	}
	
	fileprivate var errorMessage: String {
		if let errorPointer = sqlite3_errmsg(dbPointer) {
			let errorMessage = String(cString: errorPointer)
			return errorMessage
		} else {
			return "No error message provided from sqlite."
		}
	}
	
	deinit {
		sqlite3_close(dbPointer)
	}
	
	static func destroyDatabase(path: String = URL.internalDB().relativePath) {
		if FileManager.default.fileExists(atPath: path) {
			do { try FileManager.default.removeItem(atPath: path) }
			catch { print("Could not destroy database file: \(path)") }
		}
	}
	
//	static func export() throws -> URL {
//		let fmt = DateFormatter()
//		fmt.dateFormat = "yyyy-MM-dd"
//		let dest = FileManager.default.exportDir().appendingPathComponent("\(fmt.string(from: Date()))-dns-log.sqlite")
//		try? FileManager.default.removeItem(at: dest)
//		try FileManager.default.copyItem(at: FileManager.default.internalDB(), to: dest)
//		return dest
//	}
	
	static func open(path: String = URL.internalDB().relativePath) throws -> SQLiteDatabase {
		var db: OpaquePointer?
		//sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_SHAREDCACHE, nil)
		if sqlite3_open(path, &db) == SQLITE_OK {
			return SQLiteDatabase(dbPointer: db)
		} else {
			defer {
				if db != nil {
					sqlite3_close(db)
				}
			}
			if let errorPointer = sqlite3_errmsg(db) {
				let message = String(cString: errorPointer)
				throw SQLiteError.OpenDatabase(message: message)
			} else {
				throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
			}
		}
	}
	
	func run<T>(sql: String, bind: [DBBinding?] = [], step: (OpaquePointer) throws -> T) throws -> T {
		var statement: OpaquePointer?
		guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK,
			let stmt = statement else {
				throw SQLiteError.Prepare(message: errorMessage)
		}
		defer { sqlite3_finalize(stmt) }
		var col: Int32 = 0
		for b in bind.compactMap({$0}) {
			col += 1
			guard b.bind(stmt, col) == SQLITE_OK else {
				throw SQLiteError.Bind(message: errorMessage)
			}
		}
		return try step(stmt)
	}
	
	func ifStep(_ stmt: OpaquePointer, _ expected: Int32) throws {
		guard sqlite3_step(stmt) == expected else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
	
	func createTable(table: SQLTable.Type) throws {
		try run(sql: table.createStatement) { try ifStep($0, SQLITE_DONE) }
	}
	
	func vacuum() {
		try? run(sql: "VACUUM;") { try ifStep($0, SQLITE_DONE) }
	}
}

protocol SQLTable {
	static var createStatement: String { get }
}


// MARK: - Bindings

protocol DBBinding {
	func bind(_ stmt: OpaquePointer, _ col: Int32) -> Int32
}

struct BindInt32 : DBBinding {
	let raw: Int32
	init(_ value: Int32) { raw = value }
	func bind(_ stmt: OpaquePointer, _ col: Int32) -> Int32 { sqlite3_bind_int(stmt, col, raw) }
}

struct BindInt64 : DBBinding {
	let raw: sqlite3_int64
	init(_ value: sqlite3_int64) { raw = value }
	func bind(_ stmt: OpaquePointer, _ col: Int32) -> Int32 { sqlite3_bind_int64(stmt, col, raw) }
}

struct BindText : DBBinding {
	let raw: String
	init(_ value: String) { raw = value }
	func bind(_ stmt: OpaquePointer, _ col: Int32) -> Int32 { sqlite3_bind_text(stmt, col, (raw as NSString).utf8String, -1, nil) }
}

struct BindTextOrNil : DBBinding {
	let raw: String?
	init(_ value: String?) { raw = value }
	func bind(_ stmt: OpaquePointer, _ col: Int32) -> Int32 { sqlite3_bind_text(stmt, col, (raw == nil) ? nil : (raw! as NSString).utf8String, -1, nil) }
}

// MARK: - Easy Access func

private extension SQLiteDatabase {
	func readText(_ stmt: OpaquePointer, _ col: Int32) -> String? {
		let val = sqlite3_column_text(stmt, col)
		return (val != nil ? String(cString: val!) : nil)
	}
	
	func allRows<T>(_ stmt: OpaquePointer, _ fn: (OpaquePointer) -> T) -> [T] {
		var r: [T] = []
		while (sqlite3_step(stmt) == SQLITE_ROW) { r.append(fn(stmt)) }
		return r
	}
	
	func allRowsKeyed<T,U>(_ stmt: OpaquePointer, _ fn: (OpaquePointer) -> (key: T, value: U)) -> [T:U] {
		var r: [T:U] = [:]
		while (sqlite3_step(stmt) == SQLITE_ROW) { let (k,v) = fn(stmt); r[k] = v }
		return r
	}
}

extension SQLiteDatabase {
	func initScheme() {
		try? self.createTable(table: DNSQueryT.self)
		try? self.createTable(table: DNSFilterT.self)
		try? self.createTable(table: Recording.self)
		try? self.createTable(table: RecordingLog.self)
	}
}


// MARK: - DNSQueryT

private struct DNSQueryT: SQLTable {
	let ts: Timestamp
	let domain: String
	let wasBlocked: Bool
	let options: FilterOptions
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS req(
		ts INTEGER DEFAULT (strftime('%s','now')),
		domain TEXT NOT NULL,
		logOpt INTEGER DEFAULT 0
		);
		"""
	}
}

struct GroupedDomain {
	let domain: String, total: Int32, blocked: Int32, lastModified: Timestamp
	var options: FilterOptions? = nil
}

extension SQLiteDatabase {
	
	// MARK: insert
	
	func insertDNSQuery(_ domain: String, blocked: Bool) throws {
		try? run(sql: "INSERT INTO req (domain, logOpt) VALUES (?, ?);",
				 bind: [BindText(domain), BindInt32(blocked ? 1 : 0)]) {
			try ifStep($0, SQLITE_DONE)
		}
	}
	
	// MARK: delete
	
	func destroyContent() throws {
		try? run(sql: "DROP TABLE IF EXISTS req;") { try ifStep($0, SQLITE_DONE) }
		try? createTable(table: DNSQueryT.self)
	}
	
	/// Delete rows matching `ts >= ? AND "domain" OR "*.domain"`
	@discardableResult func deleteRows(matching domain: String, since ts: Timestamp = 0) throws -> Int32 {
		try run(sql: "DELETE FROM req WHERE ts >= ? AND (domain = ? OR domain LIKE '%.' || ?);",
				bind: [BindInt64(ts), BindText(domain), BindText(domain)]) { stmt -> Int32 in
			try ifStep(stmt, SQLITE_DONE)
			return sqlite3_changes(dbPointer)
		}
	}
	
	// MARK: read
	
	private func allDomainsGrouped(_ clause: String = "", bind: [DBBinding?] = []) -> [GroupedDomain]? {
		try? run(sql: "SELECT domain, COUNT(*), SUM(logOpt&1), MAX(ts) FROM req \(clause) GROUP BY domain ORDER BY 4 DESC;", bind: bind) {
			allRows($0) {
				GroupedDomain(domain: readText($0, 0) ?? "",
							  total: sqlite3_column_int($0, 1),
							  blocked: sqlite3_column_int($0, 2),
							  lastModified: sqlite3_column_int64($0, 3))
			}
		}
	}
	
	func domainList(since ts: Timestamp = 0) -> [GroupedDomain]? {
		ts==0 ? allDomainsGrouped() : allDomainsGrouped("WHERE ts >= ?", bind: [BindInt64(ts)])
	}
	
	/// Get grouped domains matching `ts >= ? AND "domain" OR "*.domain"`
	func domainList(matching domain: String, since ts: Timestamp = 0) -> [GroupedDomain]? {
		allDomainsGrouped("WHERE ts >= ? AND (domain = ? OR domain LIKE '%.' || ?)",
						  bind: [BindInt64(ts), BindText(domain), BindText(domain)])
	}
	
	/// From `ts1` (including) and up to `ts2` (excluding). `ts1 >= X < ts2`
	func domainList(between ts1: Timestamp, and ts2: Timestamp) -> [GroupedDomain]? {
		allDomainsGrouped("WHERE ts >= ? AND ts < ?", bind: [BindInt64(ts1), BindInt64(ts2)])
	}
	
	func timesForDomain(_ fullDomain: String, since ts: Timestamp = 0) -> [GroupedTsOccurrence]? {
		try? run(sql: "SELECT ts, COUNT(ts), SUM(logOpt>0) FROM req WHERE ts >= ? AND domain = ? GROUP BY ts;",
				 bind: [BindInt64(ts), BindText(fullDomain)]) {
			allRows($0) {
				(sqlite3_column_int64($0, 0), sqlite3_column_int($0, 1), sqlite3_column_int($0, 2))
			}
		}
	}
}

typealias GroupedTsOccurrence = (ts: Timestamp, total: Int32, blocked: Int32)


// MARK: - DNSFilterT

private struct DNSFilterT: SQLTable {
	let domain: String
	let options: FilterOptions
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS filter(
		domain TEXT UNIQUE NOT NULL,
		opt INTEGER DEFAULT 0
		);
		"""
	}
}

extension SQLiteDatabase {
	
	// MARK: read
	
	func loadFilters() -> [String : FilterOptions]? {
		try? run(sql: "SELECT domain, opt FROM filter;") {
			allRowsKeyed($0) {
				(key: readText($0, 0) ?? "",
				 value: FilterOptions(rawValue: sqlite3_column_int($0, 1)))
			}
		}
	}
	
	// MARK: write
	
	func setFilter(_ domain: String, _ value: FilterOptions?) {
		func removeFilter() {
			try? run(sql: "DELETE FROM filter WHERE domain = ? LIMIT 1;",
					 bind: [BindText(domain)]) { stmt -> Void in
				sqlite3_step(stmt)
			}
		}
		guard let rv = value?.rawValue, rv > 0 else {
			removeFilter()
			return
		}
		func createFilter() throws {
			try run(sql: "INSERT OR FAIL INTO filter (domain, opt) VALUES (?, ?);",
					bind: [BindText(domain), BindInt32(rv)]) {
				try ifStep($0, SQLITE_DONE)
			}
		}
		func updateFilter() {
			try? run(sql: "UPDATE filter SET opt = ? WHERE domain = ? LIMIT 1;",
					 bind: [BindInt32(rv), BindText(domain)]) { stmt -> Void in
				sqlite3_step(stmt)
			}
		}
		do { try createFilter() } catch { updateFilter() }
	}
}


// MARK: - Recordings

struct Recording: SQLTable {
	let id: sqlite3_int64
	let start: Timestamp
	let stop: Timestamp?
	var appId: String? = nil
	var title: String? = nil
	var notes: String? = nil
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS rec(
		id INTEGER PRIMARY KEY,
		start INTEGER DEFAULT (strftime('%s','now')),
		stop INTEGER,
		appid TEXT,
		title TEXT,
		notes TEXT
		);
		"""
	}
}

extension SQLiteDatabase {
	
	// MARK: write
	
	func startNewRecording() throws -> Recording {
		try run(sql: "INSERT INTO rec (stop) VALUES (NULL);") { stmt -> Recording in
			try ifStep(stmt, SQLITE_DONE)
			return try getRecording(withID: sqlite3_last_insert_rowid(dbPointer))
		}
	}
	
	func stopRecording(_ r: inout Recording) {
		guard r.stop == nil else { return }
		let theID = r.id
		try? run(sql: "UPDATE rec SET stop = (strftime('%s','now')) WHERE id = ? LIMIT 1;",
				 bind: [BindInt64(theID)]) { stmt -> Void in
			try ifStep(stmt, SQLITE_DONE)
			r = try getRecording(withID: theID)
		}
	}
	
	func updateRecording(_ r: Recording) {
		try? run(sql: "UPDATE rec SET title = ?, appid = ?, notes = ? WHERE id = ? LIMIT 1;",
				 bind: [BindTextOrNil(r.title), BindTextOrNil(r.appId), BindTextOrNil(r.notes), BindInt64(r.id)]) { stmt -> Void in
			sqlite3_step(stmt)
		}
	}
	
	func deleteRecording(_ r: Recording) throws -> Bool {
		_ = try? deleteRecordingLogs(r.id)
		return try run(sql: "DELETE FROM rec WHERE id = ? LIMIT 1;", bind: [BindInt64(r.id)]) {
			try ifStep($0, SQLITE_DONE)
			return sqlite3_changes(dbPointer) > 0
		}
	}
	
	// MARK: read
	
	func readRecording(_ stmt: OpaquePointer) -> Recording {
		let end = sqlite3_column_int64(stmt, 2)
		return Recording(id: sqlite3_column_int64(stmt, 0),
						 start: sqlite3_column_int64(stmt, 1),
						 stop: end == 0 ? nil : end,
						 appId: readText(stmt, 3),
						 title: readText(stmt, 4),
						 notes: readText(stmt, 5))
	}
	
	func ongoingRecording() -> Recording? {
		try? run(sql: "SELECT * FROM rec WHERE stop IS NULL LIMIT 1;") {
			try ifStep($0, SQLITE_ROW)
			return readRecording($0)
		}
	}
	
	func allRecordings() -> [Recording]? {
		try? run(sql: "SELECT * FROM rec WHERE stop IS NOT NULL;") {
			allRows($0) { readRecording($0) }
		}
	}
	
	func getRecording(withID: sqlite3_int64) throws -> Recording {
		try run(sql: "SELECT * FROM rec WHERE id = ? LIMIT 1;", bind: [BindInt64(withID)]) {
			try ifStep($0, SQLITE_ROW)
			return readRecording($0)
		}
	}
}

// MARK:

private struct RecordingLog: SQLTable {
	let rID: Int32
	let ts: Timestamp
	let domain: String
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS recLog(
		rid INTEGER REFERENCES rec(id) ON DELETE CASCADE,
		ts INTEGER,
		domain TEXT
		);
		"""
	}
}

extension SQLiteDatabase {

	// MARK: write

	func persistRecordingLogs(_ r: Recording) {
		guard let end = r.stop else {
			return
		}
		try? run(sql: """
			INSERT INTO recLog (rid, ts, domain) SELECT ?, ts, domain FROM req
			WHERE req.ts >= ? AND req.ts <= ?
			""", bind: [BindInt64(r.id), BindInt64(r.start), BindInt64(end)]) {
			try ifStep($0, SQLITE_DONE)
		}
	}
	
	func deleteRecordingLogs(_ recId: sqlite3_int64, matchingDomain d: String? = nil) throws -> Int32 {
		try run(sql: "DELETE FROM recLog WHERE rid = ? \(d==nil ? "" : "AND domain = ?");",
				bind: [BindInt64(recId), d==nil ? nil : BindText(d!)]) {
			try ifStep($0, SQLITE_DONE)
			return sqlite3_changes(dbPointer)
		}
	}
	
	// MARK: read
	
	func getRecordingsLogs(_ r: Recording) -> [RecordLog]? {
		try? run(sql: "SELECT domain, COUNT() FROM recLog WHERE rid = ? GROUP BY domain;",
				 bind: [BindInt64(r.id)]) {
			allRows($0) { (readText($0, 0), sqlite3_column_int($0, 1)) }
		}
	}
}

typealias RecordLog = (domain: String?, count: Int32)
