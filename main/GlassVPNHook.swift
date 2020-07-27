import Foundation

class GlassVPNHook {
	
	private let queue = DispatchQueue.init(label: "PSIGlassDNSQueue", qos: .userInteractive, target: .main)
	
	private var filterDomains: [String]!
	private var filterOptions: [(block: Bool, ignore: Bool, customA: Bool, customB: Bool)]!
	private var autoDeleteTimer: Timer? = nil
	private var cachedNotify: CachedConnectionAlert!
	
	init() { reset() }
	
	/// Reload from stored settings and rebuilt binary search tree
	private func reset() {
		reloadDomainFilter()
		setAutoDelete(PrefsShared.AutoDeleteLogsDays)
		cachedNotify = CachedConnectionAlert()
	}
	
	/// Invalidate auto-delete timer and release stored properties. You should nullify this instance afterwards.
	func cleanUp() {
		filterDomains = nil
		filterOptions = nil
		autoDeleteTimer?.fire() // one last time before we quit
		autoDeleteTimer?.invalidate()
		cachedNotify = nil
	}
	
	/// Call this method from `PacketTunnelProvider.handleAppMessage(_:completionHandler:)`
	func handleAppMessage(_ messageData: Data) {
		let message = String(data: messageData, encoding: .utf8)
		if let msg = message, let i = msg.firstIndex(of: ":") {
			let action = msg.prefix(upTo: i)
			let value = msg.suffix(from: msg.index(after: i))
			switch action {
			case "filter-update":
				reloadDomainFilter() // TODO: reload only selected domain?
				return
			case "auto-delete":
				setAutoDelete(Int(value) ?? PrefsShared.AutoDeleteLogsDays)
				return
			case "notify-prefs-change":
				cachedNotify = CachedConnectionAlert()
				return
			default: break
			}
		}
		NSLog("[VPN.WARN] This should never happen! Received unknown handleAppMessage: \(message ?? messageData.base64EncodedString())")
		reset() // just in case we fallback to do everything
	}
	
	
	// MARK: - Process DNS Request
	
	/// Log domain request and post notification (if enabled).
	/// - Returns: `true` if the request shoud be blocked.
	func processDNSRequest(_ domain: String) -> Bool {
		let i = filterIndex(for: domain)
		// TODO: disable ignore & block during recordings
		let (block, ignore, cA, cB) = (i<0) ? (false, false, false, false) : filterOptions[i]
		if ignore {
			return block
		}
		queue.async {
			do { try AppDB?.logWrite(domain, blocked: block) }
			catch { NSLog("[VPN.WARN] Couldn't write: \(error)") }
		}
		cachedNotify.postOrIgnore(domain, blck: block, custA: cA, custB: cB)
		// TODO: wait for notify response to block or allow connection
		return block
	}
	
	/// Build binary tree for reverse DNS lookup
	private func reloadDomainFilter() {
		let tmp = AppDB?.loadFilters()?.map({
			(String($0.reversed()), $1)
		}).sorted(by: { $0.0 < $1.0 }) ?? []
		let t1 = tmp.map { $0.0 }
		let t2 = tmp.map { ($1.contains(.blocked),
							$1.contains(.ignored),
							$1.contains(.customA),
							$1.contains(.customB)) }
		filterDomains = t1
		filterOptions = t2
	}

	/// Lookup for reverse DNS binary tree
	private func filterIndex(for domain: String) -> Int {
		let reverseDomain = String(domain.reversed())
		var lo = 0, hi = filterDomains.count - 1
		while lo <= hi {
			let mid = (lo + hi)/2
			if filterDomains[mid] < reverseDomain {
				lo = mid + 1
			} else if reverseDomain < filterDomains[mid] {
				hi = mid - 1
			} else {
				return mid
			}
		}
		if lo > 0, reverseDomain.hasPrefix(filterDomains[lo - 1] + ".") {
			return lo - 1
		}
		return -1
	}
	
	
	// MARK: - Auto-delete Timer
	
	/// Prepare auto-delete timer with interval between 1 hr - 1 day.
	/// - Parameter days: Max age to keep when deleting
	private func setAutoDelete(_ days: Int) {
		autoDeleteTimer?.invalidate()
		guard days > 0 else { return }
		// Repeat interval uses days as hours. min 1 hr, max 24 hrs.
		let interval = TimeInterval(min(24, days) * 60 * 60)
		autoDeleteTimer = Timer.scheduledTimer(timeInterval: interval,
											   target: self, selector: #selector(autoDeleteNow),
											   userInfo: days, repeats: true)
		autoDeleteTimer!.fire()
	}
	
	/// Callback fired when old data should be deleted.
	@objc private func autoDeleteNow(_ sender: Timer) {
		NSLog("[VPN.INFO] Auto-delete old logs")
		queue.async {
			do {
				try AppDB?.dnsLogsDeleteOlderThan(days: sender.userInfo as! Int)
			} catch {
				NSLog("[VPN.WARN] Couldn't delete logs, will retry in 5 minutes. \(error)")
				if sender.isValid {
					sender.fireDate = Date().addingTimeInterval(300) // retry in 5 min
				}
			}
		}
	}
}
