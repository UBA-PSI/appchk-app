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
