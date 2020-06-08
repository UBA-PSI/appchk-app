import Foundation

var currentVPNState: VPNState = .off
let sync = SyncUpdate(periodic: 7)

public enum VPNState : Int {
	case on = 1, inbetween, off
}

struct Pref {
	static func Int(_ key: String) -> Int { UserDefaults.standard.integer(forKey: key) }
	static func Int(_ val: Int, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	static func Bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
	static func Bool(_ val: Bool, _ key: String) { UserDefaults.standard.set(val, forKey: key) }
	
	struct DidShowTutorial {
		static var Welcome: Bool {
			get { Pref.Bool("didShowTutorialAppWelcome") }
			set { Pref.Bool(newValue, "didShowTutorialAppWelcome") }
		}
		static var Recordings: Bool {
			get { Pref.Bool("didShowTutorialRecordings") }
			set { Pref.Bool(newValue, "didShowTutorialRecordings") }
		}
	}
	struct DateFilter {
		static var Kind: DateFilterKind {
			get { DateFilterKind(rawValue: Pref.Int("dateFilterType"))! }
			set { Pref.Int(newValue.rawValue, "dateFilterType") }
		}
		/// Default: `0` (disabled)
		static var LastXMin: Int {
			get { Pref.Int("dateFilterLastXMin") }
			set { Pref.Int(newValue, "dateFilterLastXMin") }
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
		
		/// Return selected timestamp filter or `nil` if filtering is disabled.
		/// - Returns: `Timestamp.now() - LastXMin * 60`
		static func lastXMinTimestamp() -> Timestamp? {
			if Kind != .LastXMin { return nil }
			return Timestamp.past(minutes: Pref.DateFilter.LastXMin)
		}
	}
}
enum DateFilterKind: Int {
	case Off = 0, LastXMin = 1, ABRange = 2;
}
enum DateFilterOrderBy: Int {
	case Date = 0, Name = 1, Count = 2;
}
