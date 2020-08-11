import Foundation
import UIKit

extension URL {
	static func appStoreSearch(query: String) -> URL {
		// https://itunes.apple.com/lookup?bundleId=...
		URL.make("https://itunes.apple.com/search", params: [
			"media" : "software",
			"limit" : "25",
			"country" : NSLocale.current.regionCode ?? "DE",
			"version" : "2",
			"term" : query,
		])!
	}
}

struct AppStoreSearch {
	struct Result {
		let bundleId, name: String
		let developer, imageURL: String?
	}
	
	static func search(_ term: String, _ closure: @escaping ([Result]?) -> Void) {
		URLSession.shared.dataTask(with: .init(url: .appStoreSearch(query: term))) { data, response, error in
			guard let data = data, error == nil,
				let response = response as? HTTPURLResponse,
				(200 ..< 300) ~= response.statusCode else {
					closure(nil)
					return
			}
			closure(jsonSearchToList(data))
		}.resume()
	}
	
	private static func jsonSearchToList(_ data: Data) -> [Result]? {
		guard let json = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? [String: Any],
			let resAll = json["results"] as? [Any] else {
			return nil
		}
		return resAll.compactMap {
			guard let res = $0 as? [String: Any],
				let bndl = res["bundleId"] as? String,
				let name = res["trackName"] as? String // trackCensoredName
				else {
					return nil
			}
			let seller = res["sellerName"] as? String // artistName
			let image = res["artworkUrl60"] as? String // artworkUrl100
			return Result(bundleId: bndl, name: name, developer: seller, imageURL: image)
		}
	}
}
