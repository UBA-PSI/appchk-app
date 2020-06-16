import Foundation

enum RecordingsDB {
	/// Get last started recording (where `start` is set, but `stop` is not)
	static func getCurrent() -> Recording? { AppDB?.recordingGetOngoing() }
	
	/// Create new recording and set `start` timestamp to `now()`
	static func startNew() -> Recording? { try? AppDB?.recordingStartNew() }
	
	/// Finalize recording by setting the `stop` timestamp to `now()`
	static func stop(_ r: inout Recording) { AppDB?.recordingStop(&r) }
	
	/// Get list of all recordings
	static func list() -> [Recording] { AppDB?.recordingGetAll() ?? [] }
	
	/// Copy log entries from generic `heap` table  to recording specific `recLog` table
	static func persist(_ r: Recording) {
		sync.syncNow { // persist changes in cache before copying recording details
			AppDB?.recordingLogsPersist(r)
		}
	}
	
	/// Get list of domains that occured during the recording
	static func details(_ r: Recording) -> [RecordLog] {
		AppDB?.recordingLogsGetGrouped(r) ?? []
	}
	
	/// Update `title`, `appid`, and `notes` and post `NotifyRecordingChanged` notification.
	static func update(_ r: Recording) {
		AppDB?.recordingUpdate(r)
		NotifyRecordingChanged.post((r, false))
	}
	
	/// Delete whole recording including all entries and post `NotifyRecordingChanged` notification.
	static func delete(_ r: Recording) {
		if (try? AppDB?.recordingDelete(r)) == true {
			NotifyRecordingChanged.post((r, true))
		}
	}
	
	/// Delete individual entries from recording while keeping the recording alive.
	/// - Returns: `true` if at least one row is deleted.
	static func deleteDetails(_ r: Recording, domain: String) -> Bool {
		((try? AppDB?.recordingLogsDelete(r.id, matchingDomain: domain)) ?? 0) > 0
	}
}

