import Foundation

var currentVPNState: VPNState = .off
let sync = SyncUpdate(periodic: 7)

public enum VPNState : Int {
	case on = 1, inbetween, off
}

enum Pref {
	static func Int(_ key: String) -> Int { UserDefaults.standard.integer(forKey: key) }
	static func Int(_ val: Int, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	static func Bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
	static func Bool(_ val: Bool, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	static func `Any`(_ key: String) -> Any? { UserDefaults.standard.object(forKey: key) }
	static func `Any`(_ val: Any?, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	
	enum DidShowTutorial {
		static var Welcome: Bool {
			get { Pref.Bool("didShowTutorialAppWelcome") }
			set { Pref.Bool(newValue, "didShowTutorialAppWelcome") }
		}
		static var Recordings: Bool {
			get { Pref.Bool("didShowTutorialRecordings") }
			set { Pref.Bool(newValue, "didShowTutorialRecordings") }
		}
	}
	enum DateFilter {
		static var Kind: DateFilterKind {
			get { DateFilterKind(rawValue: Pref.Int("dateFilterType"))! }
			set { Pref.Int(newValue.rawValue, "dateFilterType") }
		}
		/// Default: `0` (disabled)
		static var LastXMin: Int {
			get { Pref.Int("dateFilterLastXMin") }
			set { Pref.Int(newValue, "dateFilterLastXMin") }
		}
		/// Default: `nil` (disabled)
		static var RangeA: Timestamp? {
			get { Pref.Any("dateFilterRangeA") as? Timestamp }
			set { Pref.Any(newValue, "dateFilterRangeA") }
		}
		/// Default: `nil` (disabled)
		static var RangeB: Timestamp? {
			get { Pref.Any("dateFilterRangeB") as? Timestamp }
			set { Pref.Any(newValue, "dateFilterRangeB") }
		}
		/// default: `.Date`
		static var OrderBy: DateFilterOrderBy {
			get { DateFilterOrderBy(rawValue: Pref.Int("dateFilterOderType"))! }
			set { Pref.Int(newValue.rawValue, "dateFilterOderType") }
		}
		/// default: `false` (Desc)
		static var OrderAsc: Bool {
			get { Pref.Bool("dateFilterOderAsc") }
			set { Pref.Bool(newValue, "dateFilterOderAsc") }
		}
		
		/// - Returns: Timestamp restriction depending on current selected date filter.
		///   - `Off` : `(0, -1)`
		///   - `LastXMin` : `(now-LastXMin, -1)`
		///   - `ABRange` : `(RangeA, RangeB)`
		static func restrictions() -> (type: DateFilterKind, earliest: Timestamp, latest: Timestamp) {
			let type = Kind
			switch type {
			case .Off:      return (type, 0, -1)
			case .LastXMin: return (type, Timestamp.past(minutes: Pref.DateFilter.LastXMin), -1)
			case .ABRange:  return (type, Pref.DateFilter.RangeA ?? 0, Pref.DateFilter.RangeB ?? -1)
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
