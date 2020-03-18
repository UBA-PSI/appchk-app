import Foundation
import UIKit

private let fm = FileManager.default
private let documentsDir = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
private let bundleInfoDir = documentsDir.appendingPathComponent("bundleInfo", isDirectory:true)


struct AppInfoType : Decodable {
	var id: String
	var name: String?
	var seller: String?
	var imageURL: URL?
	private var remoteImgURL: String?
	private var cache: Bool?
	private let localJSON: URL
	private let localImgURL: URL
	
	static func initWorkingDir() {
		try? fm.createDirectory(at: bundleInfoDir, withIntermediateDirectories: true, attributes: nil)
//		print("init dir: \(bundleInfoDir)")
	}
	
	init(id: String) {
		self.id = id
		if id == "" {
			name = "–?–"
			cache = true
			localJSON = URL(fileURLWithPath: "")
			localImgURL = localJSON
		} else {
			localJSON = bundleInfoDir.appendingPathComponent("\(id).json")
			localImgURL = bundleInfoDir.appendingPathComponent("\(id).img")
			reload()
		}
	}
	
	mutating func reload() {
		if fm.fileExists(atPath: localImgURL.path) {
			imageURL = localImgURL
		}
		guard name == nil, seller == nil,
			fm.fileExists(atPath: localJSON.path),
			let attr = try? fm.attributesOfItem(atPath: localJSON.path),
			attr[FileAttributeKey.size] as! UInt64 > 0 else
		{
			// process json only if attributes not set yet,
			// OR json doesn't exist, OR json is empty
			return
		}
		(name, seller, remoteImgURL) = parseJSON(localJSON)
		
		if remoteImgURL == nil || imageURL != nil {
			cache = true
		}
	}
	
	func getImage() -> UIImage? {
		if let img = imageURL, let data = try? Data(contentsOf: img) {
			return UIImage(data: data, scale: 2.0)
		} else if id.hasPrefix("com.apple.") {
			return appIconApple
		} else {
			return appIconUnknown
		}
	}
	
	private func parseJSON(_ location: URL) -> (name: String?, seller: String?, image: String?) {
		do {
			let data = try Data.init(contentsOf: location)
			if
				let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any],
				let resAll = json["results"] as? [Any],
				let res = resAll.first as? [String: Any]
			{
				let name = res["trackName"] as? String // trackCensoredName
				let seller = res["sellerName"] as? String // artistName
				let image = res["artworkUrl60"] as? String // artworkUrl100
				return (name, seller, image)
			} else if id.hasPrefix("com.apple.") {
				return (String(id.dropFirst(10)), "Apple Inc.", nil)
			}
		} catch {}
		return (nil, nil, nil)
	}
	
	mutating func updateIfNeeded(_ updateClosure: () -> Void) {
		guard cache == nil,
			let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			return
		}
		cache = false // meaning: hasn't downloaded yet, but is about to do
//		print("downloading \(id)")
		_ = downloadURL("https://itunes.apple.com/lookup?bundleId=\(safeId)", toFile: localJSON).flatMap{
//			print("downloading \(id) done.")
			reload()
			updateClosure()
			return downloadURL(remoteImgURL, toFile: localImgURL)
		}.map{
//			print("downloading \(id) image done.")
			reload()
			updateClosure()
		}
	}
	
	enum NetworkError: Error {
		case url
    }
	
	private func downloadURL(_ urlStr: String?, toFile: URL) -> Result<Void, Error> {
		guard let urlStr = urlStr, let url = URL(string: urlStr) else {
			return .failure(NetworkError.url)
		}
		var result: Result<Void, Error>!
		let semaphore = DispatchSemaphore(value: 0)
		URLSession.shared.downloadTask(with: url) { location, response, error in
			if let loc = location {
				try? fm.removeItem(at: toFile)
				try? fm.moveItem(at: loc, to: toFile)
				result = .success(())
			} else {
				result = .failure(error!)
			}
			semaphore.signal()
		}.resume()
		_ = semaphore.wait(wallTimeout: .distantFuture)
		return result
	}
}
