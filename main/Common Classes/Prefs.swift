import Foundation

enum Prefs {
	private static func Int(_ key: String) -> Int { UserDefaults.standard.integer(forKey: key) }
	private static func Int(_ val: Int, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	private static func Bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
	private static func Bool(_ val: Bool, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	private static func `Any`(_ key: String) -> Any? { UserDefaults.standard.object(forKey: key) }
	private static func `Any`(_ val: Any?, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	
	enum DidShowTutorial {
		static var Welcome: Bool {
			get { Prefs.Bool("didShowTutorialAppWelcome") }
			set { Prefs.Bool(newValue, "didShowTutorialAppWelcome") }
		}
		static var Recordings: Bool {
			get { Prefs.Bool("didShowTutorialRecordings") }
			set { Prefs.Bool(newValue, "didShowTutorialRecordings") }
		}
	}
	enum ContextAnalyis {
		static var CoOccurrenceTime: Int? {
			get { Prefs.Any("contextAnalyisCoOccurrenceTime") as? Int }
			set { Prefs.Any(newValue, "contextAnalyisCoOccurrenceTime") }
		}
	}
	enum DateFilter {
		static var Kind: DateFilterKind {
			get { DateFilterKind(rawValue: Prefs.Int("dateFilterType"))! }
			set { Prefs.Int(newValue.rawValue, "dateFilterType") }
		}
		/// Default: `0` (disabled)
		static var LastXMin: Int {
			get { Prefs.Int("dateFilterLastXMin") }
			set { Prefs.Int(newValue, "dateFilterLastXMin") }
		}
		/// Default: `nil` (disabled)
		static var RangeA: Timestamp? {
			get { Prefs.Any("dateFilterRangeA") as? Timestamp }
			set { Prefs.Any(newValue, "dateFilterRangeA") }
		}
		/// Default: `nil` (disabled)
		static var RangeB: Timestamp? {
			get { Prefs.Any("dateFilterRangeB") as? Timestamp }
			set { Prefs.Any(newValue, "dateFilterRangeB") }
		}
		/// default: `.Date`
		static var OrderBy: DateFilterOrderBy {
			get { DateFilterOrderBy(rawValue: Prefs.Int("dateFilterOderType"))! }
			set { Prefs.Int(newValue.rawValue, "dateFilterOderType") }
		}
		/// default: `false` (Desc)
		static var OrderAsc: Bool {
			get { Prefs.Bool("dateFilterOderAsc") }
			set { Prefs.Bool(newValue, "dateFilterOderAsc") }
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
enum DateFilterKind: Int {
	case Off = 0, LastXMin = 1, ABRange = 2;
}
enum DateFilterOrderBy: Int {
	case Date = 0, Name = 1, Count = 2;
}
