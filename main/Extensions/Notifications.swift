import Foundation

let NotifyVPNStateChanged = NSNotification.Name("GlassVPNStateChanged") // nil!
let NotifyDNSFilterChanged = NSNotification.Name("PSIDNSFilterSettingsChanged") // domain: String!
let NotifyDateFilterChanged = NSNotification.Name("PSIDateFilterSettingsChanged") // nil!
let NotifySortOrderChanged = NSNotification.Name("PSIDateFilterSortOrderChanged") // nil!
let NotifyRecordingChanged = NSNotification.Name("PSIRecordingChanged") // (Recording, deleted: Bool)!


extension NSNotification.Name {
	func post(_ obj: Any? = nil) {
		NotificationCenter.default.post(name: self, object: obj)
	}
	func postAsyncMain(_ obj: Any? = nil) {
		DispatchQueue.main.async { NotificationCenter.default.post(name: self, object: obj) }
	}
	/// You are responsible for removing the returned object in a `deinit` block.
//	@discardableResult func observe(queue: OperationQueue? = nil, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
//		NotificationCenter.default.addObserver(forName: self, object: nil, queue: queue, using: block)
//	}
	/// On iOS 9.0+ you don't need to unregister the observer.
	func observe(call: Selector, on target: Any, obj: Any? = nil) {
		NotificationCenter.default.addObserver(target, selector: call, name: self, object: obj)
	}
}
