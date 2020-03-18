import Foundation
import SQLite3

let exportPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
let basePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.de.uni-bamberg.psi.AppCheck")
let DB_PATH = basePath!.appendingPathComponent("dns-logs.sqlite").relativePath

typealias Timestamp = Int64
struct GroupedDomain {
	let domain: String, total: Int32, blocked: Int32, lastModified: Timestamp
	var options: FilterOptions? = nil
}

struct FilterOptions: OptionSet {
    let rawValue: Int32
    static let none    = FilterOptions(rawValue: 0)
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

var AppDB: SQLiteDatabase? { get { try? SQLiteDatabase.open(path: DB_PATH) } }

class SQLiteDatabase {
	private let dbPointer: OpaquePointer?
	private init(dbPointer: OpaquePointer?) {
//		print("SQLite path: \(basePath!.absoluteString)")
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
//		SQLiteDatabase.destroyDatabase(path: DB_PATH)
	}
	
	static func destroyDatabase(path: String) {
		if FileManager.default.fileExists(atPath: path) {
			do { try FileManager.default.removeItem(atPath: path) }
			catch { print("Could not destroy database file: \(path)") }
		}
	}
	
//	static func export() throws -> URL {
//		let fmt = DateFormatter()
//		fmt.dateFormat = "yyyy-MM-dd"
//		let dest = exportPath.appendingPathComponent("\(fmt.string(from: Date()))-dns-log.sqlite")
//		try? FileManager.default.removeItem(at: dest)
//		try FileManager.default.copyItem(atPath: DB_PATH, toPath: dest.relativePath)
//		return dest
//	}
	
	static func open(path: String) throws -> SQLiteDatabase {
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
	
	func run<T>(sql: String, bind: ((OpaquePointer) -> Bool)?, step: (OpaquePointer) throws -> T) throws -> T {
		var statement: OpaquePointer?
		guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK,
			let stmt = statement else {
				throw SQLiteError.Prepare(message: errorMessage)
		}
		defer { sqlite3_finalize(stmt) }
		guard bind?(stmt) ?? true else {
			throw SQLiteError.Bind(message: errorMessage)
		}
		return try step(stmt)
	}
	
	func ifStep(_ stmt: OpaquePointer, _ expected: Int32) throws {
		guard sqlite3_step(stmt) == expected else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
	
	func createTable(table: SQLTable.Type) throws {
		try run(sql: table.createStatement, bind: nil) {
			try ifStep($0, SQLITE_DONE)
		}
	}
	
	func vacuum() {
		try? run(sql: "VACUUM;", bind: nil) { try ifStep($0, SQLITE_DONE) }
	}
}

protocol SQLTable {
	static var createStatement: String { get }
}


// MARK: - Easy Access func

private extension SQLiteDatabase {
	func bindInt(_ stmt: OpaquePointer, _ col: Int32, _ value: Int32) -> Bool {
		sqlite3_bind_int(stmt, col, value) == SQLITE_OK
	}
	
	func bindInt64(_ stmt: OpaquePointer, _ col: Int32, _ value: sqlite3_int64) -> Bool {
		sqlite3_bind_int64(stmt, col, value) == SQLITE_OK
	}
	
	func bindText(_ stmt: OpaquePointer, _ col: Int32, _ value: String) -> Bool {
		sqlite3_bind_text(stmt, col, (value as NSString).utf8String, -1, nil) == SQLITE_OK
	}
	
	func readText(_ stmt: OpaquePointer, _ col: Int32) -> String? {
		let val = sqlite3_column_text(stmt, col)
		return (val != nil ? String(cString: val!) : nil)
	}
	
	func readGroupedDomain(_ stmt: OpaquePointer) -> GroupedDomain {
		GroupedDomain(domain: readText(stmt, 0) ?? "",
					  total: sqlite3_column_int(stmt, 1),
					  blocked: sqlite3_column_int(stmt, 2),
					  lastModified: sqlite3_column_int64(stmt, 3))
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


// MARK: - DNSQuery

struct DNSQuery: SQLTable {
	let ts: Timestamp
	let domain: String
	let wasBlocked: Bool
	let options: FilterOptions
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS req(
		ts BIGINT DEFAULT (strftime('%s','now')),
		domain VARCHAR(255) NOT NULL,
		logOpt INT DEFAULT 0
		);
		"""
	}
}

extension SQLiteDatabase {
	
	// MARK: insert
	
	func insertDNSQuery(_ domain: String, blocked: Bool) throws {
		try? run(sql: "INSERT INTO req (domain, logOpt) VALUES (?, ?);", bind: {
			self.bindText($0, 1, domain) && self.bindInt($0, 2, blocked ? 1 : 0)
		}) {
			try ifStep($0, SQLITE_DONE)
		}
	}
	
	// MARK: delete
	
	func destroyContent() throws {
		try? run(sql: "DROP TABLE IF EXISTS req;", bind: nil) {
			try ifStep($0, SQLITE_DONE)
		}
		try? createTable(table: DNSQuery.self)
	}
	
	/// Delete rows matching `ts >= ? AND "domain" OR "*.domain"`
	@discardableResult func deleteRows(matching domain: String, since ts: Timestamp = 0) throws -> Int32 {
		try run(sql: "DELETE FROM req WHERE ts >= ? AND (domain = ? OR domain LIKE '%.' || ?);", bind: {
			self.bindInt64($0, 1, ts) && self.bindText($0, 2, domain) && self.bindText($0, 3, domain)
		}) { stmt -> Int32 in
			try ifStep(stmt, SQLITE_DONE)
			return sqlite3_changes(dbPointer)
		}
	}
	
	// MARK: read
	
	func domainList(since ts: Timestamp = 0) -> [GroupedDomain]? {
		try? run(sql: "SELECT domain, COUNT(*), SUM(logOpt&1), MAX(ts) FROM req \(ts == 0 ? "" : "WHERE ts > ?") GROUP BY domain ORDER BY 4 DESC;", bind: {
			ts == 0 || self.bindInt64($0, 1, ts)
		}) {
			allRows($0) { readGroupedDomain($0) }
		}
	}
	
	func domainList(matching domain: String) -> [GroupedDomain]? {
		try? run(sql: "SELECT domain, COUNT(*), SUM(logOpt&1), MAX(ts) FROM req WHERE (domain = ? OR domain LIKE '%.' || ?) GROUP BY domain ORDER BY 4 DESC;", bind: {
			self.bindText($0, 1, domain) && self.bindText($0, 2, domain)
		}) {
			allRows($0) { readGroupedDomain($0) }
		}
	}
	
	func timesForDomain(_ fullDomain: String) -> [(Timestamp, Bool)]? {
		try? run(sql: "SELECT ts, logOpt FROM req WHERE domain = ?;", bind: {
			self.bindText($0, 1, fullDomain)
		}) {
			allRows($0) { (sqlite3_column_int64($0, 0), sqlite3_column_int($0, 1) > 0) }
		}
	}
}


// MARK: - DNSFilter

struct DNSFilter: SQLTable {
	let domain: String
	let options: FilterOptions
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS filter(
		domain VARCHAR(255) UNIQUE NOT NULL,
		opt INT DEFAULT 0
		);
		"""
	}
}

extension SQLiteDatabase {
	
	// MARK: read
	
	func loadFilters() -> [String : FilterOptions]? {
		try? run(sql: "SELECT domain, opt FROM filter ORDER BY domain ASC;", bind: nil) {
			allRowsKeyed($0) {
				(key: readText($0, 0) ?? "",
				 value: FilterOptions(rawValue: sqlite3_column_int($0, 1)))
			}
		}
	}
	
	// MARK: write
	
	func setFilter(_ domain: String, _ value: FilterOptions?) {
		func removeFilter() {
			try? run(sql: "DELETE FROM filter WHERE domain = ? LIMIT 1;", bind: {
				self.bindText($0, 1, domain)
			}) { stmt -> Void in
				sqlite3_step(stmt)
			}
		}
		guard let rv = value?.rawValue, rv > 0 else {
			removeFilter()
			return
		}
		func createFilter() throws {
			try run(sql: "INSERT OR FAIL INTO filter (domain, opt) VALUES (?, ?);", bind: {
				self.bindText($0, 1, domain) && self.bindInt($0, 2, rv)
			}) {
				try ifStep($0, SQLITE_DONE)
			}
		}
		func updateFilter() {
			try? run(sql: "UPDATE filter SET opt = ? WHERE domain = ? LIMIT 1;", bind: {
				self.bindInt($0, 1, rv) && self.bindText($0, 2, domain)
			}) { stmt -> Void in
				sqlite3_step(stmt)
			}
		}
		do { try createFilter() } catch { updateFilter() }
	}
}
