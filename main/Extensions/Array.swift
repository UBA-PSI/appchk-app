import Foundation

//extension Collection {
//	subscript(ifExist i: Index?) -> Iterator.Element? {
//		guard let i = i else { return nil }
//		return indices.contains(i) ? self[i] : nil
//	}
//}

extension Range where Bound == Int {
	@inline(__always) func arr() -> [Bound] { self.map { $0 } }
}


// MARK: - Sorted Array

extension Array {
	typealias CompareFn = (Element, Element) -> Bool
	
	/// Binary tree search operation.
	/// - Warning: Array must be sorted already.
	/// - Parameters:
	///   - mustExist: Determine whether to return low index or `nil` if element is missing.
	///   - first: If `true`, keep searching for first matching element.
	/// - Returns: Index or `nil` (only  if `mustExist = true` and element does not exist).
	/// - Complexity: O(log *n*), where *n* is the length of the array.
	func binTreeIndex(of element: Element, compare fn: CompareFn, mustExist: Bool = false, findFirst: Bool = false) -> Int? {
		var found = false
		var lo = 0, hi = self.count - 1
		while lo <= hi {
			let mid = (lo + hi)/2
			if fn(self[mid], element) {
				lo = mid + 1
			} else if fn(element, self[mid]) {
				hi = mid - 1
			} else {
				if !findFirst { return mid } // exit early if we dont care about first index
				hi = mid - 1
				found = true
			}
		}
		return (mustExist && !found) ? nil : lo // not found, would be inserted at position lo
	}
	
	/// Binary tree lookup whether element exists. Performs `binTreeIndex(of:compare:mustExist:)` internally.
	func binTreeExists(_ element: Element, compare fn: CompareFn) -> Bool {
		binTreeIndex(of: element, compare: fn, mustExist: true) != nil
	}
	
	/// Binary tree  insert operation
	/// - Warning: Array must be sorted already.
	/// - Returns: Index at which `elem` was inserted
	/// - Complexity: O(log *n*), where *n* is the length of the array.
	@discardableResult mutating func binTreeInsert(_ elem: Element, compare fn: CompareFn) -> Int {
		let newIndex = binTreeIndex(of: elem, compare: fn)!
		insert(elem, at: newIndex)
		return newIndex
	}
	
	/// Binary tree  remove operation
	/// - Warning: Array must be sorted already.
	/// - Returns: Index of removed `elem` or `nil` if it does not exist
	/// - Complexity: O(log *n*), where *n* is the length of the array.
	@discardableResult mutating func binTreeRemove(_ elem: Element, compare fn: CompareFn) -> Int? {
		if let i = binTreeIndex(of: elem, compare: fn, mustExist: true) {
			remove(at: i)
			return i
		}
		return nil
	}
	
	/// Sorted synchronous comparison between elements
	/// - Parameter sortedSubset: Must be a strict subset of the sorted array.
	/// - Returns: List of elements that are **not**  present in `sortedSubset`.
	/// - Complexity: O(*m*+*n*), where *n* is the length of the array and *m* the length of the `sortedSubset`.
	///               If indices are found earlier, *n* may be significantly less (on average: `n/2`)
	func difference(toSubset sortedSubset: [Element], compare fn: CompareFn) -> [Element] {
		var result: [Element] = []
		var iter = makeIterator()
		for rhs in sortedSubset {
			while let lhs = iter.next(), fn(lhs, rhs) {
				result.append(lhs)
			}
		}
		return result
	}
}
