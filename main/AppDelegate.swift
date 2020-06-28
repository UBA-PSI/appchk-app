import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		if UserDefaults.standard.bool(forKey: "kill_db") {
			UserDefaults.standard.set(false, forKey: "kill_db")
			SQLiteDatabase.destroyDatabase()
		}
		if let db = AppDB {
			db.initCommonScheme()
			db.initAppOnlyScheme()
		}
		
		#if IOS_SIMULATOR
		TestDataSource.load()
		#endif
		
		sync.start()
		return true
	}
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		TheGreatDestroyer.deleteLogs(olderThan: PrefsShared.AutoDeleteLogsDays)
	}
}
