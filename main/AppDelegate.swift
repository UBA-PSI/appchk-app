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
		
		Prefs.registerDefaults()
		PrefsShared.registerDefaults()
		
		#if IOS_SIMULATOR
		TestDataSource.load()
		#endif
		
		sync.start()
		return true
	}
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		TheGreatDestroyer.deleteLogs(olderThan: PrefsShared.AutoDeleteLogsDays)
		// FIXME: Does not reflect changes performed by GlassVPN auto-delete while app is open.
		//        It will update whenever app restarts or becomes active again (only if deleteLogs has something to delete!)
		//        This is a known issue and tolerated.
	}
}
