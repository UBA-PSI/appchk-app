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

extension FileManager {
	func sizeOf(path: String) -> Int64? {
		try? attributesOfItem(atPath: path)[.size] as? Int64
	}
	func readableSizeOf(path: String) -> String? {
		guard let fSize = sizeOf(path: path) else { return nil }
		let bcf = ByteCountFormatter()
		bcf.countStyle = .file
		return bcf.string(fromByteCount: fSize)
	}
}

extension URL {
//	static func exportDir() -> URL { FileManager.default.exportDir() }
	static func appGroupDir() -> URL { FileManager.default.appGroupDir() }
	static func internalDB() -> URL { FileManager.default.internalDB() }
}
