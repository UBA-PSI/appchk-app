import Foundation

var currentVPNState: VPNState = .off
let sync = SyncUpdate(periodic: 7)

public enum VPNState : Int {
	case on = 1, inbetween, off
}

struct Pref {
	struct DidShowTutorial {
		static var Welcome: Bool {
			get { UserDefaults.standard.bool(forKey: "didShowTutorialAppWelcome") }
			set { UserDefaults.standard.set(newValue, forKey: "didShowTutorialAppWelcome") }
		}
		static var Recordings: Bool {
			get { UserDefaults.standard.bool(forKey: "didShowTutorialRecordings") }
			set { UserDefaults.standard.set(newValue, forKey: "didShowTutorialRecordings") }
		}
	}
	struct DateFilter {
		static var Kind: DateFilterKind {
			get { DateFilterKind(rawValue: UserDefaults.standard.integer(forKey: "dateFilterType"))! }
			set { UserDefaults.standard.set(newValue.rawValue, forKey: "dateFilterType") }
		}
		static var LastXMin: Int {
			get { UserDefaults.standard.integer(forKey: "dateFilterLastXMin") }
			set { UserDefaults.standard.set(newValue, forKey: "dateFilterLastXMin") }
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
