import Foundation

fileprivate extension FileManager {
//	func exportDir() -> URL {
//		try! url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//	}
	func appGroupDir() -> URL {
		containerURL(forSecurityApplicationGroupIdentifier: "group.de.uni-bamberg.psi.AppCheck")!
	}
	func internalDB() -> URL {
		appGroupDir().appendingPathComponent("dns-logs.sqlite")
	}
}

extension URL {
//	static func exportDir() -> URL { FileManager.default.exportDir() }
	static func appGroupDir() -> URL { FileManager.default.appGroupDir() }
	static func internalDB() -> URL { FileManager.default.internalDB() }
}
