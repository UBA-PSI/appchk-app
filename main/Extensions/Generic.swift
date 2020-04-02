import Foundation

struct QLog {
	private init() {}
	static func m(_ message: String) { write("", message) }
	static func Info(_ message: String) { write("[INFO] ", message) }
#if DEBUG
	static func Debug(_ message: String) { write("[DEBUG] ", message) }
#else
	static func Debug(_ _: String) {}
#endif
	static func Error(_ message: String) { write("[ERROR] ", message) }
	static func Warning(_ message: String) { write("[WARN] ", message) }
	private static func write(_ tag: String, _ message: String) {
		print(String(format: "%1.3f %@%@", Date().timeIntervalSince1970, tag, message))
	}
}

extension Collection {
	subscript(ifExist i: Index?) -> Iterator.Element? {
		guard let i = i else { return nil }
		return indices.contains(i) ? self[i] : nil
	}
}

var listOfSLDs: [String : [String : Bool]] = {
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

extension String {
	/// Check if string is equal to `domain` or ends with `.domain`
	func isSubdomain(of domain: String) -> Bool { self == domain || self.hasSuffix("." + domain) }
	/// Split string into top level domain part and host part
	func splitDomainAndHost() -> (domain: String, host: String?) {
		let lastChr = last?.asciiValue ?? 0
		guard lastChr > UInt8(ascii: "9") || lastChr < UInt8(ascii: "0") else { // IP address
			return (domain: "# IP connection", host: self)
		}
		var parts = components(separatedBy: ".")
		guard let tld = parts.popLast(), let sld = parts.popLast() else {
			return (domain: self, host: nil) // no subdomains, just plain SLD
		}
		var ending = sld + "." + tld
		if listOfSLDs[tld]?[sld] ?? false, let rld = parts.popLast() {
			ending = rld + "." + ending
		}
		return (domain: ending, host: parts.joined(separator: "."))
	}
	/// Returns `true` if String matches list of known second level domains (e.g., `co.uk`).
	func isKnownSLD() -> Bool {
		let parts = components(separatedBy: ".")
		return parts.count == 2 && listOfSLDs[parts.last!]?[parts.first!] ?? false
	}
}

extension Timer {
	@discardableResult static func repeating(_ interval: TimeInterval, call selector: Selector, on target: Any, userInfo: Any? = nil) -> Timer {
		Timer.scheduledTimer(timeInterval: interval, target: target, selector: selector,
							 userInfo: userInfo, repeats: true)
	}
}

extension DateFormatter {
	convenience init(withFormat: String) {
		self.init()
		dateFormat = withFormat
	}
	func with(format: String) -> Self {
		dateFormat = format
		return self
	}
	func string(from ts: Timestamp) -> String {
		string(from: Date.init(timeIntervalSince1970: Double(ts)))
	}
}

struct TimeFormat {
	static func from(_ duration: Timestamp) -> String {
		String(format: "%02d:%02d", duration / 60, duration % 60)
	}
	static func from(_ duration: TimeInterval, millis: Bool = false) -> String {
		let t = Int(duration)
		if millis {
			let mil = Int(duration * 1000) % 1000
			return String(format: "%02d:%02d.%03d", t / 60, t % 60, mil)
		}
		return String(format: "%02d:%02d", t / 60, t % 60)
	}
	static func since(_ date: Date, millis: Bool = false) -> String {
		from(Date().timeIntervalSince(date), millis: millis)
	}
	
}
