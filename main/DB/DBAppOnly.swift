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
	
	fileprivate func col_ts(_ stmt: OpaquePointer, _ col: Int32) -> Timestamp {
		sqlite3_column_int64(stmt, col)
	}
}

class WhereClauseBuilder: CustomStringConvertible {
	var description: String = ""
	private let prefix: String
	private(set) var bindings: [DBBinding] = []
	
	init(prefix p: String = "WHERE") { prefix = "\(p) " }
	
	/// Append new clause by either prepending `WHERE` prefix or placing `AND` between clauses.
	@discardableResult func and(_ clause: String, _ bind: DBBinding ...) -> Self {
		description.append((description=="" ? prefix : " AND ") + clause)
		bindings.append(contentsOf: bind)
		return self
	}
	/// Restrict to `rowid >= {range}.start AND rowid <= {range}.end`.
	/// Omitted if range is `nil` or individually if a value is `0`.
	@discardableResult func and(in range: SQLiteRowRange) -> Self {
		if range.start != 0 { and("rowid >= ?", BindInt64(range.start)) }
		if range.end != 0 { and("rowid <= ?", BindInt64(range.end)) }
		return self
	}
	/// Restrict to `ts >= {min} AND ts < {max}`. Omit one or the other if value is `0`.
	@discardableResult func and(min: Timestamp = 0, max: Timestamp = 0) -> Self {
		if min != 0 { and("ts >= ?", BindInt64(min)) }
		if max != 0 { and("ts < ?", BindInt64(max)) }
		return self
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
typealias DomainTsPair = (domain: String, ts: Timestamp)

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
		let Where = WhereClauseBuilder().and(min: ts)
		Where.and("\(strict ? "fqdn" : "domain") = ?", BindText(domain)) // (fqdn = ? OR fqdn LIKE '%.' || ?)
		return (try? run(sql: "DELETE FROM heap \(Where);", bind: Where.bindings) { stmt -> Int32 in
			try ifStep(stmt, SQLITE_DONE)
			return numberOfChanges
		}) ?? 0
	}
	
	// MARK: read
	
	/// `SELECT min(ts) FROM heap`
	func dnsLogsMinDate() -> Timestamp? {
		try? run(sql:"SELECT min(ts) FROM heap") {
			try ifStep($0, SQLITE_ROW)
			return col_ts($0, 0)
		}
	}
	
	/// Select min and max row id with given condition `ts >= ? AND ts < ?`
	/// - Parameters:
	///   - ts1: Restrict min `rowid` to `ts >= ?`. Pass `0` to omit restriction.
	///   - ts2: Restrict max `rowid` to `ts < ?`. Pass `0` to omit restriction.
	///   - range: If set, only look at the specified range. Default: `(0,0)`
	/// - Returns: `nil` in case no rows are matching the condition
	func dnsLogsRowRange(between ts1: Timestamp, and ts2: Timestamp, within range: SQLiteRowRange = (0,0)) -> SQLiteRowRange? {
		let Where = WhereClauseBuilder().and(in: range).and(min: ts1, max: ts2)
		return try? run(sql:"SELECT min(rowid), max(rowid) FROM heap \(Where);", bind: Where.bindings) {
			try ifStep($0, SQLITE_ROW)
			let max = col_ts($0, 1)
			return (max == 0) ? nil : (col_ts($0, 0), max)
		}
	}
	
	/// Get raw logs between two timestamps. `ts >= ? AND ts <= ?`
	/// - Returns: List sorted by `ts` in descending order (newest entries first).
	func dnsLogs(between ts1: Timestamp, and ts2: Timestamp) -> [DomainTsPair]? {
		try? run(sql: "SELECT fqdn, ts FROM heap WHERE ts >= ? AND ts <= ? ORDER BY ts DESC, rowid ASC;",
				 bind: [BindInt64(ts1), BindInt64(ts2)]) {
			allRows($0) {
				(col_text($0, 0) ?? "", col_ts($0, 1))
			}
		}
	}
	
	/// Group DNS logs by domain, count occurences and number of blocked requests.
	/// - Parameters:
	///   - range: Whenever possible set range to improve SQL lookup times. `start <= rowid <= end `
	///   - matchingDomain: Restrict `(fqdn|domain) = ?`. Which column is used is determined by `parentDomain`.
	///   - parentDomain: If `nil` returns `domain` column. Else returns `fqdn` column with restriction on `domain == parentDomain`.
	/// - Returns: List of grouped domains with no particular sorting order.
	func dnsLogsGrouped(range: SQLiteRowRange, matchingDomain: String? = nil, parentDomain: String? = nil) -> [GroupedDomain]? {
		let Where = WhereClauseBuilder().and(in: range)
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
				GroupedDomain(domain: col_text($0, 0) ?? "",
							  total: sqlite3_column_int($0, 1),
							  blocked: sqlite3_column_int($0, 2),
							  lastModified: col_ts($0, 3))
			}
		}
	}
	
	/// Get list or individual DNS entries. Mutliple entries in the very same second are grouped.
	/// - Parameters:
	///   - fqdn: Exact match for domain name `fqdn = ?`
	///   - range: Whenever possible set range to improve SQL lookup times. `start <= rowid <= end `
	/// - Returns: List sorted by reverse timestamp order (newest first)
	func timesForDomain(_ fqdn: String, range: SQLiteRowRange) -> [GroupedTsOccurrence]? {
		let Where = WhereClauseBuilder().and(in: range).and("fqdn = ?", BindText(fqdn))
		return try? run(sql: "SELECT ts, COUNT(ts), COUNT(opt) FROM heap \(Where) GROUP BY ts ORDER BY ts DESC;", bind: Where.bindings) {
			allRows($0) {
				(col_ts($0, 0), sqlite3_column_int($0, 1), sqlite3_column_int($0, 2))
			}
		}
	}
}



// MARK: - Context Analysis

typealias ContextAnalysisResult = (domain: String, count: Int32, avg: Double, rank: Double)

extension SQLiteDatabase {
	/// Number of times how often given `fqdn` appears in the database
	func dnsLogsCount(fqdn: String) -> Int? {
		try? run(sql: "SELECT COUNT(*) FROM heap WHERE fqdn = ?;", bind: [BindText(fqdn)]) {
			try ifStep($0, SQLITE_ROW)
			return Int(sqlite3_column_int($0, 0))
		}
	}
	
	/// Get sorted, unique list of `ts` with given `fqdn`.
	func dnsLogsUniqTs(_ domain: String, isFQDN flag: Bool) -> [Timestamp]? {
		try? run(sql: "SELECT DISTINCT ts FROM heap WHERE \(flag ? "fqdn" : "domain") = ? ORDER BY ts;",
				bind: [BindText(domain)]) {
			allRows($0) { col_ts($0, 0) }
		}
	}
	
	/// Find other domains occurring regularly at roughly the same time as `fqdn`.
	/// - Warning: `times` list must be **sorted** by time in ascending order.
	/// - Parameters:
	///   - times: List of `ts` from `dnsLogsUniqTs(fqdn)`
	///   - dt: Search for `ts - dt <= X <= ts + dt`
	///   - fqdn: Rows matching this domain will be excluded from the result set.
	/// - Returns: List of tuples ordered by rank (ASC).
	func contextAnalysis(coOccurrence times: [Timestamp], plusMinus dt: Timestamp, exclude domain: String, isFQDN flag: Bool) -> [ContextAnalysisResult]? {
		guard times.count > 0 else { return nil }
		createFunction("fnDist") {
			let x = $0.first as! Timestamp
			let i = times.binTreeIndex(of: x, compare: <)!
			let dist: Timestamp
			switch i {
			case 0:           dist = times[0] - x
			case times.count: dist = x - times[i-1]
			default:          dist = min(times[i] - x, x - times[i-1])
			}
			return dist
		}
		// `avg ^ 2`:   prefer results that are closer to `times`
		// `_ / count`: prefer results with higher occurrence count
		// `time / 2`:  Weighting factor (low: prefer close, high: prefer count)
		//              `time` helpful esp. for smaller spans. `avg^2` will raise faster anyway.
		let fnRank = "(avg * avg + (? / 2.0) + 1) / count" // +1 in case time == 0 -> avg^2 == 0
		// improve query by excluding entries that are: before the first, or after the last ts
		let low = times.first! - dt
		let high = times.last! + dt
		return try? run(sql: """
			SELECT fqdn, count, avg, (\(fnRank)) rank FROM (
				SELECT fqdn, COUNT(*) count, AVG(dist) avg FROM (
					SELECT fqdn, fnDist(ts) dist FROM heap
					WHERE ts BETWEEN ? AND ? AND \(flag ? "fqdn" : "domain") != ? AND dist <= ?
				) GROUP BY fqdn
			) ORDER BY rank ASC LIMIT 99;
			""", bind: [BindInt64(dt), BindInt64(low), BindInt64(high), BindText(domain), BindInt64(dt)]) {
				allRows($0) {
					(col_text($0, 0) ?? "", sqlite3_column_int($0, 1), sqlite3_column_double($0, 2), sqlite3_column_double($0, 3))
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
		let end = col_ts(stmt, 2)
		return Recording(id: sqlite3_column_int64(stmt, 0),
						 start: col_ts(stmt, 1),
						 stop: end == 0 ? nil : end,
						 appId: col_text(stmt, 3),
						 title: col_text(stmt, 4),
						 notes: col_text(stmt, 5))
	}
	
	/// `WHERE stop IS NULL`
	func recordingGetOngoing() -> Recording? {
		try? run(sql: "SELECT * FROM rec WHERE stop IS NULL LIMIT 1;") {
			try ifStep($0, SQLITE_ROW)
			return readRecording($0)
		}
	}
	
	/// Get `Timestamp` of last recording.
	func recordingLastTimestamp() -> Timestamp? {
		try? run(sql: "SELECT stop FROM rec WHERE stop IS NOT NULL ORDER BY rowid DESC LIMIT 1;") {
			try ifStep($0, SQLITE_ROW)
			return col_ts($0, 0)
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
	
	/// Delete one recording log entry with given `recording id`, matching `domain`, and `ts`.
	/// - Returns: `true` if row was deleted
	func recordingLogsDelete(_ recId: sqlite3_int64, singleEntry ts: Timestamp, domain: String) throws -> Bool {
		try run(sql: "DELETE FROM recLog WHERE rid = ? AND ts = ? AND domain = ? LIMIT 1;",
				bind: [BindInt64(recId), BindInt64(ts), BindText(domain)]) {
			try ifStep($0, SQLITE_DONE)
			return numberOfChanges > 0
		}
	}
	
	// MARK: read
	
	/// List of domains and count occurences for given recording.
	/// - Returns: List of `(domain, ts)` pairs. Sorted by `ts` in ascending order (oldest first)
	func recordingLogsGet(_ r: Recording) -> [DomainTsPair]? {
		try? run(sql: "SELECT domain, ts FROM recLog WHERE rid = ? ORDER BY ts ASC, rowid DESC;",
				 bind: [BindInt64(r.id)]) {
			allRows($0) { (col_text($0, 0) ?? "", col_ts($0, 1)) }
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
