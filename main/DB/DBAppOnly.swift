import Foundation
import SQLite3

typealias Timestamp = sqlite3_int64

extension SQLiteDatabase {
	func initAppOnlyScheme() {
		try? run(sql: CreateTable.heap)
		try? run(sql: CreateTable.rec)
		try? run(sql: CreateTable.recLog)
		do {
			try migrateDB()
		} catch {
			QLog.Error("during migration: \(error)")
		}
	}
	
	func migrateDB() throws {
		let version = try run(sql: "PRAGMA user_version;") { stmt -> Int32 in
			try ifStep(stmt, SQLITE_ROW)
			return sqlite3_column_int(stmt, 0)
		}
		if version != 1 {
			// version 0 -> 1: req(domain) -> heap(fqdn, domain)
			if version == 0 {
				try tempMigrate()
			}
			try run(sql: "PRAGMA user_version = 1;")
		}
	}

	private func tempMigrate() throws { // TODO: remove with next internal release
		do {
			try run(sql: "SELECT 1 FROM req LIMIT 1;") // fails if req doesnt exist
			createFunction("domainof") { ($0.first as! String).extractDomain() }
			try run(sql: """
				BEGIN TRANSACTION;
				INSERT INTO heap(ts,fqdn,domain,opt) SELECT ts,domain,domainof(domain),nullif(logOpt,0) FROM req;
				DROP TABLE req;
				COMMIT;
				""")
		} catch { /* no need to migrate */ }
	}
}

private enum TableName: String {
	case heap, cache
}

extension SQLiteDatabase {
	fileprivate func lastRowId(_ table: TableName) -> SQLiteRowID {
		(try? run(sql:"SELECT rowid FROM \(table.rawValue) ORDER BY rowid DESC LIMIT 1;") {
			try ifStep($0, SQLITE_ROW)
			return sqlite3_column_int64($0, 0)
		}) ?? 0
	}
}

struct WhereClauseBuilder: CustomStringConvertible {
	var description: String = ""
	private let prefix: String
	private(set) var bindings: [DBBinding] = []
	init(prefix p: String = "WHERE") { prefix = "\(p) " }
	mutating func and(_ clause: String, _ bind: DBBinding ...) {
		description.append((description=="" ? prefix : " AND ") + clause)
		bindings.append(contentsOf: bind)
	}
}



// MARK: - DNSLog

extension CreateTable {
	/// `ts`: Timestamp,  `fqdn`: String,  `domain`: String,  `opt`: Int
	static var heap: String {"""
		CREATE TABLE IF NOT EXISTS heap(
			ts INTEGER DEFAULT (strftime('%s','now')),
			fqdn TEXT NOT NULL,
			domain TEXT NOT NULL,
			opt INTEGER
		);
		"""} // opt currently only used as "blocked" flag
}

struct GroupedDomain {
	let domain: String, total: Int32, blocked: Int32, lastModified: Timestamp
	var options: FilterOptions? = nil
}
typealias GroupedTsOccurrence = (ts: Timestamp, total: Int32, blocked: Int32)

extension SQLiteDatabase {
	
	// MARK: write
	
	/// Move newest entries from `cache` to `heap` and return range (in `heap`) of newly inserted entries.
	/// - Returns: `nil`  in case no entries were transmitted.
	@discardableResult func dnsLogsPersist() -> SQLiteRowRange? {
		guard lastRowId(.cache) > 0 else { return nil }
		let before = lastRowId(.heap) + 1
		createFunction("domainof") { ($0.first as! String).extractDomain() }
		try? run(sql:"""
			BEGIN TRANSACTION;
			INSERT INTO heap(ts,fqdn,domain,opt) SELECT ts,dns,domainof(dns),nullif(opt&1,0) FROM cache;
			DELETE FROM cache;
			COMMIT;
			""")
		let after = lastRowId(.heap)
		return (before > after) ? nil : (before, after)
	}
	
	/// `DELETE FROM cache; DELETE FROM heap;`
	func dnsLogsDeleteAll() throws {
		try? run(sql: "DELETE FROM cache; DELETE FROM heap;")
		vacuum()
	}
	
	/// Delete rows matching `ts >= ? AND domain = ?`
	/// - Parameter strict: If `true`, use `fqdn` instead of `domain` column
	/// - Returns: Number of changes aka. Number of rows deleted
	@discardableResult func dnsLogsDelete(_ domain: String, strict: Bool, since ts: Timestamp = 0) -> Int32 {
		var Where = WhereClauseBuilder()
		if ts != 0 { Where.and("ts >= ?", BindInt64(ts)) }
		Where.and("\(strict ? "fqdn" : "domain") = ?", BindText(domain)) // (fqdn = ? OR fqdn LIKE '%.' || ?)
		return (try? run(sql: "DELETE FROM heap \(Where);", bind: Where.bindings) { stmt -> Int32 in
			try ifStep(stmt, SQLITE_DONE)
			return numberOfChanges
		}) ?? 0
	}
	
	// MARK: read
	
	/// Select min and max row id with given condition `ts >= ? AND ts < ?`
	/// - Returns: `nil` in case no rows are matching the condition
	func dnsLogsRowRange(between ts: Timestamp, and ts2: Timestamp) -> SQLiteRowRange? {
		try? run(sql:"SELECT min(rowid), max(rowid) FROM heap WHERE ts >= ? AND ts < ?",
				 bind: [BindInt64(ts), BindInt64(ts2)]) {
			try ifStep($0, SQLITE_ROW)
			let max = sqlite3_column_int64($0, 1)
			return (max == 0) ? nil : (sqlite3_column_int64($0, 0), max)
		}
	}
	
	/// Group DNS logs by domain, count occurences and number of blocked requests.
	/// - Parameters:
	///   - range: Whenever possible set range to improve SQL lookup times. `start <= rowid <= end `
	///   - ts: Restrict result set `ts >= ?`
	///   - ts2: Restrict result set `ts < ?`
	///   - matchingDomain: Restrict `(fqdn|domain) = ?`. Which column is used is determined by `parentDomain`.
	///   - parentDomain: If `nil` returns `domain` column. Else returns `fqdn` column with restriction on `domain == parentDomain`.
	/// - Returns: List of grouped domains with no particular sorting order.
	func dnsLogsGrouped(range: SQLiteRowRange? = nil, since ts: Timestamp = 0, upto ts2: Timestamp = 0,
						matchingDomain: String? = nil, parentDomain: String? = nil) -> [GroupedDomain]?
	{
		var Where = WhereClauseBuilder()
		if let from = range?.start { Where.and("rowid >= ?", BindInt64(from)) }
		if let to = range?.end { Where.and("rowid <= ?", BindInt64(to)) }
		if ts != 0 { Where.and("ts >= ?", BindInt64(ts)) }
		if ts2 != 0 { Where.and("ts < ?", BindInt64(ts2)) }
		let col: String // fqdn or domain
		if let parent = parentDomain { // is subdomain
			col = "fqdn"
			Where.and("domain = ?", BindText(parent))
		} else {
			col = "domain"
		}
		if let matching = matchingDomain { // (fqdn = ? OR fqdn LIKE '%.' || ?)
			Where.and("\(col) = ?", BindText(matching))
		}
		return try? run(sql: "SELECT \(col), COUNT(*), COUNT(opt), MAX(ts) FROM heap \(Where) GROUP BY \(col);", bind: Where.bindings) {
			allRows($0) {
				GroupedDomain(domain: readText($0, 0) ?? "",
							  total: sqlite3_column_int($0, 1),
							  blocked: sqlite3_column_int($0, 2),
							  lastModified: sqlite3_column_int64($0, 3))
			}
		}
	}
	
	/// Get list or individual DNS entries. Mutliple entries in the very same second are grouped.
	/// - Parameters:
	///   - fqdn: Exact match for domain name `fqdn = ?`
	///   - range: Whenever possible set range to improve SQL lookup times. `start <= rowid <= end `
	///   - ts: Restrict result set `ts >= ?`
	///   - ts2: Restrict result set `ts < ?`
	/// - Returns: List sorted by reverse timestamp order (newest first)
	func timesForDomain(_ fqdn: String, range: SQLiteRowRange? = nil, since ts: Timestamp = 0, upto ts2: Timestamp = 0) -> [GroupedTsOccurrence]? {
		var Where = WhereClauseBuilder()
		if let from = range?.start { Where.and("rowid >= ?", BindInt64(from)) }
		if let to = range?.end { Where.and("rowid <= ?", BindInt64(to)) }
		if ts != 0 { Where.and("ts >= ?", BindInt64(ts)) }
		if ts2 != 0 { Where.and("ts < ?", BindInt64(ts2)) }
		Where.and("fqdn = ?", BindText(fqdn))
		return try? run(sql: "SELECT ts, COUNT(ts), COUNT(opt) FROM heap \(Where) GROUP BY ts ORDER BY ts DESC;", bind: Where.bindings) {
			allRows($0) {
				(sqlite3_column_int64($0, 0), sqlite3_column_int($0, 1), sqlite3_column_int($0, 2))
			}
		}
	}
}



// MARK: - Recordings

extension CreateTable {
	/// `id`: Primary,  `start`: Timestamp,  `stop`: Timestamp,  `appid`: String,  `title`: String,  `notes`: String
	static var rec: String {"""
		CREATE TABLE IF NOT EXISTS rec(
			id INTEGER PRIMARY KEY,
			start INTEGER DEFAULT (strftime('%s','now')),
			stop INTEGER,
			appid TEXT,
			title TEXT,
			notes TEXT
		);
		"""}
}

struct Recording {
	let id: sqlite3_int64
	let start: Timestamp
	let stop: Timestamp?
	var appId: String? = nil
	var title: String? = nil
	var notes: String? = nil
}

extension SQLiteDatabase {
	
	// MARK: write
	
	/// Create new recording with `stop` set to `NULL`.
	func recordingStartNew() throws -> Recording {
		try run(sql: "INSERT INTO rec (stop) VALUES (NULL);") { stmt -> Recording in
			try ifStep(stmt, SQLITE_DONE)
			return try recordingGet(withID: lastInsertedRow)
		}
	}
	
	/// Update given recording by setting `stop` to current time.
	func recordingStop(_ r: inout Recording) {
		guard r.stop == nil else { return }
		let theID = r.id
		try? run(sql: "UPDATE rec SET stop = (strftime('%s','now')) WHERE id = ? LIMIT 1;",
				 bind: [BindInt64(theID)]) { stmt -> Void in
			try ifStep(stmt, SQLITE_DONE)
			r = try recordingGet(withID: theID)
		}
	}
	
	/// Update given recording by replacing `title`, `appid`, and `notes` with new values.
	func recordingUpdate(_ r: Recording) {
		try? run(sql: "UPDATE rec SET title = ?, appid = ?, notes = ? WHERE id = ? LIMIT 1;",
				 bind: [BindTextOrNil(r.title), BindTextOrNil(r.appId), BindTextOrNil(r.notes), BindInt64(r.id)]) { stmt -> Void in
			sqlite3_step(stmt)
		}
	}
	
	/// Delete recording and all of its entries.
	/// - Returns: `true` on success
	func recordingDelete(_ r: Recording) throws -> Bool {
		_ = try? recordingLogsDelete(r.id)
		return try run(sql: "DELETE FROM rec WHERE id = ? LIMIT 1;", bind: [BindInt64(r.id)]) {
			try ifStep($0, SQLITE_DONE)
			return numberOfChanges > 0
		}
	}
	
	// MARK: read
	
	private func readRecording(_ stmt: OpaquePointer) -> Recording {
		let end = sqlite3_column_int64(stmt, 2)
		return Recording(id: sqlite3_column_int64(stmt, 0),
						 start: sqlite3_column_int64(stmt, 1),
						 stop: end == 0 ? nil : end,
						 appId: readText(stmt, 3),
						 title: readText(stmt, 4),
						 notes: readText(stmt, 5))
	}
	
	/// `WHERE stop IS NULL`
	func recordingGetOngoing() -> Recording? {
		try? run(sql: "SELECT * FROM rec WHERE stop IS NULL LIMIT 1;") {
			try ifStep($0, SQLITE_ROW)
			return readRecording($0)
		}
	}
	
	/// `WHERE stop IS NOT NULL`
	func recordingGetAll() -> [Recording]? {
		try? run(sql: "SELECT * FROM rec WHERE stop IS NOT NULL;") {
			allRows($0) { readRecording($0) }
		}
	}
	
	/// `WHERE id = ?`
	private func recordingGet(withID: sqlite3_int64) throws -> Recording {
		try run(sql: "SELECT * FROM rec WHERE id = ? LIMIT 1;", bind: [BindInt64(withID)]) {
			try ifStep($0, SQLITE_ROW)
			return readRecording($0)
		}
	}
}



// MARK: - RecordingLog

extension CreateTable {
	/// `rid`: Reference `rec(id)`,  `ts`: Timestamp,  `domain`: String
	static var recLog: String {"""
		CREATE TABLE IF NOT EXISTS recLog(
			rid INTEGER REFERENCES rec(id) ON DELETE CASCADE,
			ts INTEGER,
			domain TEXT
		);
		"""}
}

typealias RecordLog = (domain: String, count: Int32)

extension SQLiteDatabase {

	// MARK: write
	
	/// Duplicate and copy all log entries for given recording to `recLog` table
	func recordingLogsPersist(_ r: Recording) {
		guard let end = r.stop else { return }
		// TODO: make sure cache entries get copied too.
		//       either by copying them directly from cache or perform sync first
		try? run(sql: """
			INSERT INTO recLog (rid, ts, domain) SELECT ?, ts, fqdn FROM heap
			WHERE heap.ts >= ? AND heap.ts <= ?
			""", bind: [BindInt64(r.id), BindInt64(r.start), BindInt64(end)]) {
			try ifStep($0, SQLITE_DONE)
		}
	}
	
	/// Delete all log entries with given recording id. Optional: only delete entries for a single domain
	/// - Parameter d: If `nil` remove all entries for given recording
	/// - Returns: Number of deleted rows
	func recordingLogsDelete(_ recId: sqlite3_int64, matchingDomain d: String? = nil) throws -> Int32 {
		try run(sql: "DELETE FROM recLog WHERE rid = ? \(d==nil ? "" : "AND domain = ?");",
				bind: [BindInt64(recId), d==nil ? nil : BindText(d!)]) {
			try ifStep($0, SQLITE_DONE)
			return numberOfChanges
		}
	}
	
	// MARK: read
	
	/// List of domains and count occurences for given recording.
	func recordingLogsGetGrouped(_ r: Recording) -> [RecordLog]? {
		try? run(sql: "SELECT domain, COUNT() FROM recLog WHERE rid = ? GROUP BY domain;",
				 bind: [BindInt64(r.id)]) {
			allRows($0) { (readText($0, 0) ?? "", sqlite3_column_int($0, 1)) }
		}
	}
}



// MARK: - DBSettings

//extension CreateTable {
//	static var settings: String {
//		"CREATE TABLE IF NOT EXISTS settings(key TEXT UNIQUE NOT NULL, val TEXT);"
//	}
//}
//
//extension SQLiteDatabase {
//	func getSetting(for key: String) -> String? {
//		try? run(sql: "SELECT val FROM settings WHERE key = ?;",
//				 bind: [BindText(key)]) { readText($0, 0) }
//	}
//	func setSetting(_ value: String?, for key: String) {
//		if let value = value {
//			try? run(sql: "INSERT OR REPLACE INTO settings (key, val) VALUES (?, ?);",
//					 bind: [BindText(value), BindText(key)]) { step($0) }
//		} else {
//			try? run(sql: "DELETE FROM settings WHERE key = ?;",
//					 bind: [BindText(key)]) { step($0) }
//		}
//	}
//}
