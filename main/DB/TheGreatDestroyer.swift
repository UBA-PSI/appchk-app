import Foundation

struct TheGreatDestroyer {
	
	/// Callback fired when user performs row edit -> delete action
	static func deleteLogs(domain: String, since ts: Timestamp, strict flag: Bool) {
		sync.pause()
		DispatchQueue.global().async {
			defer { sync.continue() }
			guard let db = AppDB, db.dnsLogsDelete(domain, strict: flag, since: ts) > 0 else {
				return // nothing has changed
			}
			db.vacuum()
			sync.needsReloadDB(domain: domain)
		}
	}
	
	/// Fired when user taps on Settings -> Delete All Logs
	static func deleteAllLogs() {
		sync.pause()
		DispatchQueue.global().async {
			defer { sync.continue() }
			do {
				try AppDB?.dnsLogsDeleteAll()
				sync.needsReloadDB()
			} catch {}
		}
	}
}
