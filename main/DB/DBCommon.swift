import Foundation
import SQLite3

enum CreateTable {} // used for CREATE TABLE statements

extension SQLiteDatabase {
	func initCommonScheme() {
		try? run(sql: CreateTable.cache)
		try? run(sql: CreateTable.filter)
	}
}


// MARK: - transit

extension CreateTable {
	/// `ts`: Timestamp,  `dns`: String,  `opt`: Int
	static var cache: String {"""
		CREATE TABLE IF NOT EXISTS cache(
			ts INTEGER DEFAULT (strftime('%s','now')),
			dns TEXT NOT NULL,
			opt INTEGER
		);
		"""}
}

extension SQLiteDatabase {
//	/// `INSERT INTO cache (dns, opt) VALUES (?, ?);`
//	func logWritePrepare() throws -> OpaquePointer {
//		try prepare(sql: "INSERT INTO cache (dns, opt) VALUES (?, ?);")
//	}
//	/// `prep` must exist and be initialized with `logWritePrepare()`
//	func logWrite(_ pStmt: OpaquePointer!, _ domain: String, blocked: Bool = false) throws {
//		guard let prep = pStmt else {
//			return
//		}
//		try prepared(run: prep, bind: [BindText(domain), BindInt32(blocked ? 1 : 0)])
//	}
	/// `INSERT INTO cache (dns, opt) VALUES (?, ?);`
	func logWrite(_ domain: String, blocked: Bool = false) throws {
		try self.run(sql: "INSERT INTO cache (dns, opt) VALUES (?, ?);",
			bind: [BindText(domain), BindInt32(blocked ? 1 : 0)])
		{ try ifStep($0, SQLITE_DONE) }
	}
}


// MARK: - filter

extension CreateTable {
	/// `domain`: String,  `opt`: Int
	static var filter: String {"""
		CREATE TABLE IF NOT EXISTS filter(
			domain TEXT UNIQUE NOT NULL,
			opt INTEGER
		);
		"""}
}

struct FilterOptions: OptionSet {
	let rawValue: Int32
	static let none    = FilterOptions([])
	static let blocked = FilterOptions(rawValue: 1 << 0)
	static let ignored = FilterOptions(rawValue: 1 << 1)
	static let any     = FilterOptions(rawValue: 0b11)
}

extension SQLiteDatabase {
	func loadFilters(where matching: FilterOptions? = nil) -> [String : FilterOptions]? {
		let rv = matching?.rawValue ?? 0
		return try? run(sql: "SELECT domain, opt FROM filter \(rv>0 ? "WHERE opt & ?" : "");",
						bind: rv>0 ? [BindInt32(rv)] : []) {
			allRowsKeyed($0) {
				(key: col_text($0, 0) ?? "",
				 value: FilterOptions(rawValue: sqlite3_column_int($0, 1)))
			}
		}
	}
	func setFilter(_ domain: String, _ value: FilterOptions?) {
		if let rv = value?.rawValue, rv > 0 {
			try? run(sql: "INSERT OR REPLACE INTO filter (domain, opt) VALUES (?, ?);",
					 bind: [BindText(domain), BindInt32(rv)]) { _ = sqlite3_step($0) }
		} else {
			try? run(sql: "DELETE FROM filter WHERE domain = ? LIMIT 1;",
					 bind: [BindText(domain)]) { _ = sqlite3_step($0) }
		}
	}
//	func loadFilterCount() -> (blocked: Int32, ignored: Int32)? {
//		try? run(sql: "SELECT SUM(opt&1), SUM(opt&2)/2 FROM filter;") {
//			try ifStep($0, SQLITE_ROW)
//			return (sqlite3_column_int($0, 0), sqlite3_column_int($0, 1))
//		}
//	}
}
