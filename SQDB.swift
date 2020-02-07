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
	let app: String
	let dns: String
	let ts: Int64
	static var createStatement: String {
		return """
		CREATE TABLE IF NOT EXISTS req(
		app VARCHAR(255),
		dns VARCHAR(2047),
		ts BIGINT DEFAULT (strftime('%s','now'))
		);
		"""
	}
}

extension SQLiteDatabase {
	
	func insertDNSQuery(appId: NSString, dnsQuery: NSString) throws {
		let insertSql = "INSERT INTO req (app, dns) VALUES (?, ?);"
		let insertStatement = try prepareStatement(sql: insertSql)
		defer {
			sqlite3_finalize(insertStatement)
		}
		guard
			sqlite3_bind_text(insertStatement, 1, appId.utf8String, -1, nil) == SQLITE_OK &&
				sqlite3_bind_text(insertStatement, 2, dnsQuery.utf8String, -1, nil) == SQLITE_OK
			else {
				throw SQLiteError.Bind(message: errorMessage)
		}
		guard sqlite3_step(insertStatement) == SQLITE_DONE else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
	
	func dnsQueriesForApp(appIdentifier: NSString, _ body: @escaping (DNSQuery) -> Void) {
		let querySql = "SELECT * FROM req WHERE app = ?;"
		guard let queryStatement = try? prepareStatement(sql: querySql) else {
			print("Error preparing statement for insert")
			return
		}
		defer {
			sqlite3_finalize(queryStatement)
		}
		guard sqlite3_bind_text(queryStatement, 1, appIdentifier.utf8String, -1, nil) == SQLITE_OK else {
			print("Error binding insert key")
			return
		}
		while (sqlite3_step(queryStatement) == SQLITE_ROW) {
			let appId = sqlite3_column_text(queryStatement, 0)
			let dnsQ = sqlite3_column_text(queryStatement, 1)
			let ts = sqlite3_column_int64(queryStatement, 2)
			let res = DNSQuery(app: String(cString: appId!),
							   dns: String(cString: dnsQ!),
							   ts: ts)
			body(res)
		}
	}
	
	func appList() -> [String] {
		let querySql = "SELECT DISTINCT app FROM req;"
		guard let queryStatement = try? prepareStatement(sql: querySql) else {
			print("Error preparing statement for insert")
			return []
		}
		defer {
			sqlite3_finalize(queryStatement)
		}
		var res: [String] = []
		while (sqlite3_step(queryStatement) == SQLITE_ROW) {
			let appId = sqlite3_column_text(queryStatement, 0)
			res.append(String(cString: appId!))
		}
		return res
	}
}
