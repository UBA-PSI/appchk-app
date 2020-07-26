import Foundation

class ThrottledBatchQueue<T> {
	private var cache: [T] = []
	private var scheduled: Bool = false
	private let queue: DispatchQueue
	private let delay: Double
	
	init(_ delay: Double, using queue: DispatchQueue) {
		self.queue = queue
		self.delay = delay
	}
	
	func addDelayed(_ elem: T, afterDelay closure: @escaping ([T]) -> Void) {
		queue.sync {
			cache.append(elem)
			guard !scheduled else {
				return
			}
			scheduled = true
			queue.asyncAfter(deadline: .now() + delay) {
				let aCopy = self.cache
				self.cache.removeAll(keepingCapacity: true)
				self.scheduled = false
				DispatchQueue.main.async {
					closure(aCopy)
				}
			}
		}
	}
}
