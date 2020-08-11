import Foundation

fileprivate extension FileManager {
	func documentDir() -> URL {
		try! url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	}
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
	static func documentDir() -> URL { FileManager.default.documentDir() }
	static func appGroupDir() -> URL { FileManager.default.appGroupDir() }
	static func internalDB() -> URL { FileManager.default.internalDB() }
	
	static func make(_ base: String, params: [String : String]) -> URL? {
		guard var components = URLComponents(string: base) else {
			return nil
		}
		components.queryItems = params.map {
			URLQueryItem(name: $0, value: $1)
		}
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		return components.url
	}
	
	func download(to file: URL, onSuccess: @escaping () -> Void) {
		URLSession.shared.downloadTask(with: self) { location, response, error in
			if let loc = location {
				try? FileManager.default.removeItem(at: file)
				do {
					try FileManager.default.moveItem(at: loc, to: file)
					onSuccess()
				} catch {
					NSLog("[VPN.ERROR] \(error)")
				}
			}
		}.resume()
	}
}
