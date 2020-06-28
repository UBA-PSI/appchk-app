import Foundation

enum PrefsShared {
	private static var suite: UserDefaults { UserDefaults(suiteName: "group.de.uni-bamberg.psi.AppCheck")! }
	
	private static func Int(_ key: String) -> Int { suite.integer(forKey: key) }
	private static func Int(_ val: Int, _ key: String) { suite.set(val, forKey: key) }
//	private static func Obj(_ key: String) -> Any? { suite.object(forKey: key) }
//	private static func Obj(_ val: Any?, _ key: String) { suite.set(val, forKey: key) }
	
	static var AutoDeleteLogsDays: Int {
		get { Int("AutoDeleteLogsDays") }
		set { Int(newValue, "AutoDeleteLogsDays"); suite.synchronize() }
	}
}
