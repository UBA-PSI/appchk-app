import UIKit

extension String {
	/// Check if string is equal to `domain` or ends with `.domain`
	func isSubdomain(of domain: String) -> Bool { self == domain || self.hasSuffix("." + domain) }
	
	/// Extract  second or third level domain name
	func extractDomain() -> String {
		let lastChr = last?.asciiValue ?? 0
		guard lastChr > UInt8(ascii: "9") || lastChr < UInt8(ascii: "0") else { // IP address
			return "# IP"
		}
		var parts = components(separatedBy: ".")
		guard let tld = parts.popLast(), let sld = parts.popLast() else {
			return self // no subdomains, just plain SLD
		}
		if listOfSLDs[tld]?[sld] ?? false, let rld = parts.popLast() {
			return rld + "." + sld + "." + tld
		}
		return sld + "." + tld
	}
	
	/// Returns `true` if String matches list of known second level domains (e.g., `co.uk`).
	func isKnownSLD() -> Bool {
		let parts = components(separatedBy: ".")
		return parts.count == 2 && listOfSLDs[parts.last!]?[parts.first!] ?? false
	}
	
	func isValidBundleId() -> Bool {
		let regex = try! NSRegularExpression(pattern: #"^[A-Za-z0-9\.\-]{1,155}$"#, options: .anchorsMatchLines)
		let range = NSRange(location: 0, length: self.utf16.count)
		let matches = regex.matches(in: self, options: .anchored, range: range)
		return matches.count == 1
	}
}

private var listOfSLDs: [String : [String : Bool]] = {
	let path = Bundle.main.url(forResource: "third-level", withExtension: "txt")
	let content = try! String(contentsOf: path!)
	var res: [String : [String : Bool]] = [:]
	content.enumerateLines { line, _ in
		let dom = line.split(separator: ".")
		let tld = String(dom.first!)
		let sld = String(dom.last!)
		if res[tld] == nil { res[tld] = [:] }
		res[tld]![sld] = true
	}
	return res
}()
