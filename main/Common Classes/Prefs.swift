import Foundation

enum Prefs {
	private static var suite: UserDefaults { UserDefaults.standard }
	
	private static func Int(_ key: String) -> Int { suite.integer(forKey: key) }
	private static func Int(_ key: String, _ val: Int) { suite.set(val, forKey: key) }
	private static func Bool(_ key: String) -> Bool { suite.bool(forKey: key) }
	private static func Bool(_ key: String, _ val: Bool) { suite.set(val, forKey: key) }
	private static func Str(_ key: String) -> String? { suite.string(forKey: key) }
	private static func Str(_ key: String, _ val: String?) { suite.set(val, forKey: key) }
	private static func Obj(_ key: String) -> Any? { suite.object(forKey: key) }
	private static func Obj(_ key: String, _ val: Any?) { suite.set(val, forKey: key) }
	
	static func registerDefaults() {
		suite.register(defaults: [
			"RecordingReminderEnabled" : true,
			"contextAnalyisCoOccurrenceTime" : 5,
		])
	}
}


// MARK: - Tutorial

extension Prefs {
	enum DidShowTutorial {
		static var Welcome: Bool {
			get { Prefs.Bool("didShowTutorialAppWelcome") }
			set { Prefs.Bool("didShowTutorialAppWelcome", newValue) }
		}
		static var Recordings: Bool {
			get { Prefs.Bool("didShowTutorialRecordings") }
			set { Prefs.Bool("didShowTutorialRecordings", newValue) }
		}
		static var RecordingHowTo: Bool {
			get { Prefs.Bool("didShowTutorialRecordingHowTo") }
			set { Prefs.Bool("didShowTutorialRecordingHowTo", newValue) }
		}
	}
}


// MARK: - Date Filter

enum DateFilterKind: Int {
	case Off = 0, LastXMin = 1, ABRange = 2;
}
enum DateFilterOrderBy: Int {
	case Date = 0, Name = 1, Count = 2;
}

extension Prefs {
	enum DateFilter {
		static var Kind: DateFilterKind {
			get { DateFilterKind(rawValue: Prefs.Int("dateFilterType"))! }
			set { Prefs.Int("dateFilterType", newValue.rawValue) }
		}
		/// Default: `0` (disabled)
		static var LastXMin: Int {
			get { Prefs.Int("dateFilterLastXMin") }
			set { Prefs.Int("dateFilterLastXMin", newValue) }
		}
		/// Default: `nil` (disabled)
		static var RangeA: Timestamp? {
			get { Prefs.Obj("dateFilterRangeA") as? Timestamp }
			set { Prefs.Obj("dateFilterRangeA", newValue) }
		}
		/// Default: `nil` (disabled)
		static var RangeB: Timestamp? {
			get { Prefs.Obj("dateFilterRangeB") as? Timestamp }
			set { Prefs.Obj("dateFilterRangeB", newValue) }
		}
		/// default: `.Date`
		static var OrderBy: DateFilterOrderBy {
			get { DateFilterOrderBy(rawValue: Prefs.Int("dateFilterOderType"))! }
			set { Prefs.Int("dateFilterOderType", newValue.rawValue) }
		}
		/// default: `false` (Desc)
		static var OrderAsc: Bool {
			get { Prefs.Bool("dateFilterOderAsc") }
			set { Prefs.Bool("dateFilterOderAsc", newValue) }
		}
		
		/// - Returns: Timestamp restriction depending on current selected date filter.
		///   - `Off` : `(nil, nil)`
		///   - `LastXMin` : `(now-LastXMin, nil)`
		///   - `ABRange` : `(RangeA, RangeB)`
		static func restrictions() -> (type: DateFilterKind, earliest: Timestamp?, latest: Timestamp?) {
			let type = Kind
			switch type {
			case .Off:      return (type, nil, nil)
			case .LastXMin: return (type, Timestamp.past(minutes: Prefs.DateFilter.LastXMin), nil)
			case .ABRange:  return (type, Prefs.DateFilter.RangeA, Prefs.DateFilter.RangeB)
			}
		}
	}
}


// MARK: - ContextAnalyis

extension Prefs {
	enum ContextAnalyis {
		static var CoOccurrenceTime: Int {
			get { Prefs.Int("contextAnalyisCoOccurrenceTime") }
			set { Prefs.Int("contextAnalyisCoOccurrenceTime", newValue) }
		}
	}
}


// MARK: - Notifications

extension Prefs {
	enum RecordingReminder {
		static var Enabled: Bool {
			get { Prefs.Bool("RecordingReminderEnabled") }
			set { Prefs.Bool("RecordingReminderEnabled", newValue) }
		}
		static var Sound: String {
			get { Prefs.Str("RecordingReminderSound") ?? "#default" }
			set { Prefs.Str("RecordingReminderSound", newValue) }
		}
	}
}
