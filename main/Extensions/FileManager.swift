import Foundation

fileprivate extension FileManager {
	func exportDir() -> URL {
		try! url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	}
	func appGroupDir() -> URL {
		containerURL(forSecurityApplicationGroupIdentifier: "group.de.uni-bamberg.psi.AppCheck")!
	}
	func internalDB() -> URL {
		appGroupDir().appendingPathComponent("dns-logs.sqlite")
	}
	func appGroupIPC() -> URL {
		appGroupDir().appendingPathComponent("data-exchange.dat")
	}
}

extension URL {
	static func exportDir() -> URL { FileManager.default.exportDir() }
	static func appGroupDir() -> URL { FileManager.default.appGroupDir() }
	static func internalDB() -> URL { FileManager.default.internalDB() }
	static func appGroupIPC() -> URL { FileManager.default.appGroupIPC() }
}
