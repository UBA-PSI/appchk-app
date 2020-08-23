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
	
	/// Fired when user taps on Settings -> "Delete All Logs"
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
	
	/// Fired when user changes Settings -> "Auto-delete logs" and every time the App enters foreground
	static func deleteLogs(olderThan days: Int) {
		guard days > 0 else { return }
		sync.pause()
		DispatchQueue.global().async {
			defer { sync.continue() }
			QLog.Info("Auto-delete logs")
			do {
				if try AppDB!.dnsLogsDeleteOlderThan(days: days) {
					sync.needsReloadDB()
				}
			} catch {
				QLog.Warning("Couldn't auto-delete logs, \(error)")
			}
		}
	}
}
