import Foundation
import SQLite3

//let basePath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
let basePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.de.uni-bamberg.psi.AppCheck")
public let DB_PATH = basePath!.appendingPathComponent("dnslog.sqlite").relativePath

enum SQLiteError: Error {
	case OpenDatabase(message: String)
	case Prepare(message: String)
	case Step(message: String)
	case Bind(message: String)
}

//: ## The Database Connection
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
//		SQLiteDatabase.destroyDatabase(path: DB_PATH)
	}
	
	static func destroyDatabase(path: String) {
		do {
			if FileManager.default.fileExists(atPath: path) {
				try FileManager.default.removeItem(atPath: path)
			}
		} catch {
			print("Could not destroy database file: \(path)")
		}
	}
	
	func destroyContent() throws {
		let deleteStatement = try prepareStatement(sql: "DELETE FROM req;")
		defer {
			sqlite3_finalize(deleteStatement)
		}
		guard sqlite3_step(deleteStatement) == SQLITE_DONE else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
	
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
	
	func prepareStatement(sql: String) throws -> OpaquePointer? {
		var statement: OpaquePointer?
		guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
			throw SQLiteError.Prepare(message: errorMessage)
		}
		return statement
	}
	
	func createTable(table: SQLTable.Type) throws {
		let createTableStatement = try prepareStatement(sql: table.createStatement)
		defer {
			sqlite3_finalize(createTableStatement)
		}
		guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
}

protocol SQLTable {
	static var createStatement: String { get }
}

struct DNSQuery: SQLTable {
	let ts: Int64
	let domain: String
	let host: String?
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS req(
		ts BIGINT DEFAULT (strftime('%s','now')),
		domain VARCHAR(255) NOT NULL,
		host VARCHAR(2047)
		);
		"""
	}
}

extension SQLiteDatabase {
	
	func insertDNSQuery(_ dnsQuery: String) throws {
		// Split dns query into subdomain part
		var domain: String = dnsQuery
		var host: String? = nil
		let lastChr = dnsQuery.last?.asciiValue ?? 0
		if lastChr > UInt8(ascii: "9") || lastChr < UInt8(ascii: "0") { // if not IP address
			guard let last1 = dnsQuery.lastIndex(of: ".") else {
				return
			}
			let last2 = dnsQuery[...dnsQuery.index(before: last1)].lastIndex(of: ".")
			if let idx = last2 {
				domain = String(dnsQuery.suffix(from: dnsQuery.index(after: idx)))
				host = String(dnsQuery.prefix(upTo: idx))
			}
		}
		// perform query
		let insertSql = "INSERT INTO req (domain, host) VALUES (?, ?);"
		let insertStatement = try prepareStatement(sql: insertSql)
		defer {
			sqlite3_finalize(insertStatement)
		}
		guard
			sqlite3_bind_text(insertStatement, 1, (domain as NSString).utf8String, -1, nil) == SQLITE_OK &&
			sqlite3_bind_text(insertStatement, 2, (host as NSString?)?.utf8String, -1, nil) == SQLITE_OK
			else {
				throw SQLiteError.Bind(message: errorMessage)
		}
		guard sqlite3_step(insertStatement) == SQLITE_DONE else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
	
	func domainList() -> [GroupedDomain] {
//		let querySql = "SELECT DISTINCT domain FROM req;"
		let querySql = "SELECT domain, COUNT(*), MAX(ts) FROM req GROUP BY domain ORDER BY 3 DESC;"
		guard let queryStatement = try? prepareStatement(sql: querySql) else {
			print("Error preparing statement for insert")
			return []
		}
		defer {
			sqlite3_finalize(queryStatement)
		}
		var res: [GroupedDomain] = []
		while (sqlite3_step(queryStatement) == SQLITE_ROW) {
			let d = sqlite3_column_text(queryStatement, 0)
			let c = sqlite3_column_int64(queryStatement, 1)
			let l = sqlite3_column_int64(queryStatement, 2)
			res.append(GroupedDomain(label: String(cString: d!), count: c, lastModified: l))
		}
		return res
	}
	
	func hostsForDomain(_ domain: NSString) -> [GroupedDomain] {
		let querySql = "SELECT host, COUNT(*), MAX(ts) FROM req WHERE domain = ? GROUP BY host ORDER BY 1 ASC;"
		guard let queryStatement = try? prepareStatement(sql: querySql) else {
			print("Error preparing statement for insert")
			return []
		}
		defer {
			sqlite3_finalize(queryStatement)
		}
		guard sqlite3_bind_text(queryStatement, 1, domain.utf8String, -1, nil) == SQLITE_OK else {
			print("Error binding insert key")
			return []
		}
		var res: [GroupedDomain] = []
		while (sqlite3_step(queryStatement) == SQLITE_ROW) {
			let h = sqlite3_column_text(queryStatement, 0)
			let c = sqlite3_column_int64(queryStatement, 1)
			let l = sqlite3_column_int64(queryStatement, 2)
			res.append(GroupedDomain(label: h != nil ? String(cString: h!) : "", count: c, lastModified: l))
		}
		return res
	}
	
	func timesForDomain(_ domain: String, host: String?) -> [Timestamp] {
		let querySql = "SELECT ts FROM req WHERE domain = ? AND host = ?;"
		guard let queryStatement = try? prepareStatement(sql: querySql) else {
			print("Error preparing statement for insert")
			return []
		}
		defer {
			sqlite3_finalize(queryStatement)
		}
		guard
			sqlite3_bind_text(queryStatement, 1, (domain as NSString).utf8String, -1, nil) == SQLITE_OK &&
			sqlite3_bind_text(queryStatement, 2, (host as NSString?)?.utf8String, -1, nil) == SQLITE_OK
			else {
				print("Error binding insert key")
				return []
		}
		var res: [Timestamp] = []
		while (sqlite3_step(queryStatement) == SQLITE_ROW) {
			let ts = sqlite3_column_int64(queryStatement, 0)
			res.append(ts)
		}
		return res
	}
}

typealias Timestamp = Int64
struct GroupedDomain {
	let label: String, count: Int64, lastModified: Timestamp
}
