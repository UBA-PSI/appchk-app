import UIKit

protocol FilterPipelineDelegate: UITableViewController {
	/// Currently only called when a row is moved and the `tableView` is frontmost.
	func rowNeedsUpdate(_ row: Int)
}

// MARK: FilterPipeline

class FilterPipeline<T> {
	typealias DataSourceQuery = () -> [T]

	private var sourceQuery: DataSourceQuery!
	private(set) fileprivate var dataSource: [T] = []
	
	private var pipeline: [PipelineFilter<T>] = []
	private var display: PipelineSorting<T>!
	private(set) weak var delegate: FilterPipelineDelegate?
	
	required init(withDelegate: FilterPipelineDelegate) {
		delegate = withDelegate
	}
	
	/// Set a new `dataSource` query and immediately apply all filters and sorting.
	/// - Note: You must call `reload(fromSource:)` manually!
	/// - Note: Always use `[unowned self]`
	func setDataSource(query: @escaping DataSourceQuery) {
		sourceQuery = query
	}
	
	/// - Returns: Number of elements in `projection`
	@inline(__always) func displayObjectCount() -> Int { display.projection.count }
	
	/// Dereference `projection` index to `dataSource` index
	/// - Complexity: O(1)
	@inline(__always) func displayObject(at index: Int) -> T { dataSource[display.projection[index]] }
	
	/// Search and return first element in `dataSource` that matches `predicate`.
	/// - Returns: Index in `dataSource` and found object or `nil` if no matching item found.
	/// - Complexity: O(*n*), where *n* is the length of the `dataSource`.
	func dataSourceGet(where predicate: ((T) -> Bool)) -> (index: Int, object: T)? {
		guard let i = dataSource.firstIndex(where: predicate) else {
			return nil
		}
		return (i, dataSource[i])
	}
	
	/// Search and return list of `dataSource` elements that match the given `predicate`.
	/// - Returns: Sorted list of indices and objects  in `dataSource`.
	/// - Complexity: O(*m* + *n*), where *n* is the length of the `dataSource` and *m* is the number of matches.
//	func dataSourceAll(where predicate: ((T) -> Bool)) -> [(index: Int, object: T)] {
//		dataSource.enumerated().compactMap { predicate($1) ? ($0, $1) : nil }
//	}
	
	/// Re-query data source and re-built filter and display sorting order.
	/// - Parameter fromSource: If `false` only re-built filter and sort order
	func reload(fromSource: Bool, whenDone: @escaping () -> Void) {
		DispatchQueue.global().async {
			if fromSource {
				self.dataSource = self.sourceQuery()
			}
			self.resetFilters()
			DispatchQueue.main.sync {
				self.delegate?.tableView.reloadData()
				whenDone()
			}
		}
	}
	
	/// Returns the index set of either the last filter layer, or `dataSource` if no filter is set yet.
	fileprivate func lastFilterLayerIndices() -> [Int] {
		pipeline.last?.selection ?? dataSource.indices.arr()
	}
	
	/// Get pipeline index of filter with given identifier
	private func indexOfFilter(_ identifier: String) -> Int? {
		pipeline.firstIndex(where: {$0.id == identifier})
	}
	
	
	// MARK: manage pipeline
	
	/// Add new filter layer. Each layer is applied upon the previous layer. Therefore, each filter
	/// can only restrict the display further. A filter cannot introduce previously removed elements.
	/// - Parameters:
	///   - identifier: Use this id to find the filter again. For reload and remove operations.
	///   - otherId: If `nil` or non-existent the new filter will be appended at the end.
	///   - predicate: Return `true` if you want to keep the element.
	func addFilter(_ identifier: String, before otherId: String? = nil, _ predicate: @escaping PipelineFilter<T>.Predicate) {
		let newFilter = PipelineFilter(identifier, predicate)
		if let other = otherId, let i = indexOfFilter(other) {
			pipeline.insert(newFilter, at: i)
			resetFilters(startingAt: i)
		} else {
			newFilter.reset(to: dataSource, previous: pipeline.last)
			pipeline.append(newFilter)
			display?.apply(moreRestrictive: newFilter)
		}
	}
	
	/// Find and remove filter with given identifier. Will automatically update remaining filters and display sorting.
	func removeFilter(withId ident: String) {
		if let i = indexOfFilter(ident) {
			pipeline.remove(at: i)
			if i == pipeline.count {
				// only if we don't reset other layers we can assure `toLessRestrictive`
				display?.reset(toLessRestrictive: pipeline.last)
			} else {
				resetFilters(startingAt: i)
			}
		}
	}
	
	/// Start filter evaluation on all entries from previous filter.
	func reloadFilter(withId ident: String) {
		if let i = indexOfFilter(ident) {
			resetFilters(startingAt: i)
		}
	}
	
	/// Remove last `k` filters from the filter pipeline. Thus showing more entries from previous layers.
	func popLastFilter(k: Int = 1) {
		guard k > 0, k <= pipeline.count else { return }
		pipeline.removeLast(k)
		display?.reset(toLessRestrictive: pipeline.last)
	}
	
	/// Sets the sort and display order. You should set the `delegate` to automatically update your `tableView`.
	/// - Parameter predicate: Return `true` if first element should be sorted before second element.
	func setSorting(_ predicate: @escaping PipelineSorting<T>.Predicate) {
		display = .init(predicate, pipe: self)
	}
	
	/// Re-built filter and display sorting order.
	/// - Parameter index: Must be: `index <= pipeline.count`
	private func resetFilters(startingAt index: Int = 0) {
		for i in index..<pipeline.count {
			pipeline[i].reset(to: dataSource, previous: (i>0) ? pipeline[i-1] : nil)
		}
		// Reset is NOT less-restrictive because filters are dynamic
		// Calling reset on a filter twice may yield different results
		// E.g. if filter uses variables outside of scope (current time, search term)
		display?.reset()
	}
	
	/// Push object through filter pipeline to check whether it survives all filters.
	/// - Parameter index: The index of the object in the original `dataSource`
	/// - Returns: `changed` is `true` if element persists or should be removed with this update.
	///            `display` indicates whther element should be shown (`true`) or hidden (`false`).
	/// - Complexity: O(*m* log *n*), where *m* is the number of filters and *n* the number of elements in each filter.
	private func processPipeline(with obj: T, at index: Int) -> (changed: Bool, display: Bool) {
		var keepGoing = true
		for filter in pipeline {
			let lastIndex: Int?
			if keepGoing {
				(keepGoing, lastIndex) = filter.update(obj, at: index)
			} else {
				lastIndex = filter.remove(dataSource: index)
			}
			// if it isnt in this layer, it wont appear in the following either
			if lastIndex == nil { return (false, false) }
		}
		return (true, keepGoing)
	}
	
	
	// MARK: data updates
	
	/// Add new element to the original `dataSource` and immediately apply filter and sorting.
	/// - Complexity: O((*m*+1) log *n*), where *m* is the number of filters and *n* the number of elements in each filter.
	func addNew(_ obj: T) {
		let index = dataSource.count
		dataSource.append(obj)
		for filter in pipeline {
			if filter.add(obj, at: index) == nil { return }
		}
		// survived all filters
		let displayIndex = display.insertNew(index)
		delegate?.tableView.safeInsertRow(displayIndex, with: .left)
	}
	
	/// Update element at `index` in the original `dataSource` and immediately re-apply filter and sorting.
	/// - Parameters:
	///   - obj: Element to be added. Will overwrite previous `dataSource` object.
	///   - index: Index in the original `dataSource`
	/// - Complexity: O(*n* + (*m*+1) log *n*), where *m* is the number of filters and *n* the number of elements in each filter / projection.
	func update(_ obj: T, at index: Int) {
		let status = processPipeline(with: obj, at: index)
		guard status.changed else { return }
		let oldPos = display.deleteOld(index)
		dataSource[index] = obj
		guard status.display else {
			if let old = oldPos { delegate?.tableView.safeDeleteRows([old]) }
			return
		}
		let newPos = display.insertNew(index)
		if let old = oldPos {
			if old == newPos {
				delegate?.tableView.safeReloadRow(old)
			} else {
				delegate?.tableView.safeMoveRow(old, to: newPos)
				if delegate?.tableView.isFrontmost ?? false {
					delegate?.rowNeedsUpdate(newPos)
				}
			}
		} else {
			delegate?.tableView.safeInsertRow(newPos, with: .left)
		}
	}
	
	/// Remove elements from the original `dataSource`, from all filters, and from display sorting.
	/// - Parameter sorted: Indices in the original `dataSource`
	/// - Complexity: O(*t*(*m*+*n*) + *m* log *n*), where *t* is the number of filters,
	///               *m* the number of elements in each filter / projection, and *n* the length of `sorted` indices.
	func remove(indices sorted: [Int]) {
		guard sorted.count > 0 else { return }
		for i in sorted.reversed() {
			dataSource.remove(at: i)
		}
		for filter in pipeline {
			filter.shiftRemove(indices: sorted)
		}
		let indices = display.shiftRemove(indices: sorted)
		delegate?.tableView.safeDeleteRows(indices)
	}
}


// MARK: - Filter

class PipelineFilter<T> {
	typealias Predicate = (T) -> Bool
	
	let id: String
	private(set) var selection: [Int] = []
	private let shouldPersist: Predicate
	
	/// - Parameter predicate: Return `true` if you want to keep the element
	required init(_ identifier: String, _ predicate: @escaping Predicate) {
		self.id = identifier
		shouldPersist = predicate
	}
	
	/// Reset selection indices by copying the indices from the previous filter or using
	/// the indices of the data source if no previous filter is present.
	fileprivate func reset(to dataSource: [T], previous filter: PipelineFilter<T>? = nil) {
		selection = (filter != nil) ? filter!.selection : dataSource.indices.arr()
		selection.removeAll { !shouldPersist(dataSource[$0]) }
	}
	
	/// Apply filter to `obj` and either insert or do nothing.
	/// - Parameters:
	///   - obj: Object that should be inserted if filter allows.
	///   - index: Index of object in original `dataSource`
	/// - Returns: Index in `selection` or `nil` if `obj` is removed by the filter.
	/// - Complexity:
	/// 	* O(1), if `index` is appended at end.
	/// 	* O(log *n*), where *n* is the length of the `selection`.
	fileprivate func add(_ obj: T, at index: Int) -> Int? {
		guard shouldPersist(obj) else {
			return nil
		}
		if selection.last ?? 0 < index { // in case we only append at end
			selection.append(index)
			return selection.count - 1
		}
		return selection.binTreeInsert(index, compare: (<))
	}
	
	/// Search and remove original `dataSource` index
	/// - Parameter index: Index of object in original `dataSource`
	/// - Returns: Index of removed element in `selection` or `nil` if element does not exist
	/// - Complexity: O(log *n*), where *n* is the length of the `selection`.
	fileprivate func remove(dataSource index: Int) -> Int? {
		selection.binTreeRemove(index, compare: (<))
	}
	
	/// Find `selection` index for corresponding `dataSource` index
	/// - Parameter index: Index of object in original `dataSource`
	/// - Returns: Index in `selection` or `nil` if element does not exist.
	/// - Complexity: O(log *n*), where *n* is the length of the `selection`.
	fileprivate func index(ofDataSource index: Int) -> Int? {
		selection.binTreeIndex(of: index, compare: (<), mustExist: true)
	}
	
	/// Perform filter check and update internal `selection` indices.
	/// - Parameters:
	///   - obj: Object that was inserted or updated.
	///   - index: Index where the object is located after the update.
	/// - Returns: `keep` indicates whether the value should be displayed (`true`) or hidden (`false`).
	///            `idx` contains the selection filter index or `nil` if the value should be removed.
	/// - Complexity: O(log *n*), where *n* is the length of the `selection`.
	fileprivate func update(_ obj: T, at index: Int) -> (keep: Bool, idx: Int?) {
		let currentIndex = self.index(ofDataSource: index)
		if shouldPersist(obj) {
			return (true, currentIndex ?? selection.binTreeInsert(index, compare: (<)))
		}
		if let i = currentIndex { selection.remove(at: i) }
		return (false, currentIndex)
	}
	
	/// Instead of re-sorting we can decrement all remaining elements after X.
	/// - Parameter sorted: Elements to remove from collection
	/// - Complexity: O(*m*+*n*), where *m* is the length of the `selection`.
	///               *n* is equal to: *length of selection* `-` *index of first element* of `sorted` indices
	fileprivate func shiftRemove(indices sorted: [Int]) {
		guard sorted.count > 0 else {
			return
		}
		var list = sorted
		var del = list.popLast()
		for (i, val) in selection.enumerated().reversed() {
			while let d = del, d > val {
				del = list.popLast()
			}
			guard let d = del else { break }
			if d < val { selection[i] -= (list.count + 1) }
			else if d == val { selection.remove(at: i) }
		}
	}
}


// MARK: - Sorting

class PipelineSorting<T> {
	typealias Predicate = (T, T) -> Bool
	
	private(set) var projection: [Int] = []
	private let comperator: (Int, Int) -> Bool // links to pipeline.dataSource
	private let previousLayerIndices: () -> [Int] // links to pipeline
	
	/// Create a fresh, already sorted, display order projection.
	/// - Parameter predicate: Return `true` if first element should be sorted before second element.
	required init(_ predicate: @escaping Predicate, pipe: FilterPipeline<T>) {
		comperator = { [unowned pipe] in
			predicate(pipe.dataSource[$0], pipe.dataSource[$1])
		}
		previousLayerIndices = { [unowned pipe] in
			pipe.lastFilterLayerIndices()
		}
		reset()
	}
	
	/// Apply a new layer of filtering. Every layer can only restrict the display even further.
	/// Therefore, indices that were removed in the last layer will be removed from the projection too.
	/// - Complexity: O(*m* log *n*), where *m* is the length of the `projection` and *n* the length of the `filter`.
	fileprivate func apply(moreRestrictive filter: PipelineFilter<T>) {
		projection.removeAll { filter.index(ofDataSource: $0) == nil }
	}
	
	/// Remove a layer of filtering. Previous layers are less restrictive and contain more indices.
	/// Therefore, the difference between both index sets will be inserted into the projection.
	/// - Parameter filter: If `nil`, reset to last filter layer or `dataSource`
	/// - Complexity:
	///   * O(*m* log *n*), if `filter != nil`.
	///     Where *n* is the length of the `projection` and *m* is the difference between both layers.
	///   * O(*n* log *n*), if `filter == nil`.
	///     Where *n* is the length of the previous layer (or `dataSource`).
	fileprivate func reset(toLessRestrictive filter: PipelineFilter<T>? = nil) {
		if let indices = filter?.selection.difference(toSubset: projection.sorted(), compare: (<)) {
			for idx in indices {
				insertNew(idx)
			}
		} else {
			projection = previousLayerIndices().sorted(by: comperator)
		}
	}
	
	/// Add new element and automatically sort according to predicate
	/// - Parameter index: Index of the element position in the original `dataSource`
	/// - Returns: Index in the projection
	/// - Complexity: O(log *n*), where *n* is the length of the `projection`.
	@discardableResult fileprivate func insertNew(_ index: Int) -> Int {
		projection.binTreeInsert(index, compare: comperator)
	}
	
	/// Remove element from projection
	/// - Parameter index: Index of the element position in the original `dataSource`
	/// - Returns: Index in the projection or `nil` if element did not exist
	/// - Complexity: O(*n*), where *n* is the length of the `projection`.
	fileprivate func deleteOld(_ index: Int) -> Int? {
		guard let i = projection.firstIndex(of: index) else {
			return nil
		}
		projection.remove(at: i)
		return i
	}
	
	/// Instead of re-sorting we can decrement all remaining elements after X.
	/// - Parameter sorted: Elements to remove from collection
	/// - Returns: List of `projection` indices that were removed (reverse sort order)
	/// - Complexity: O(*m* log *n*), where *m* is the length of the `projection` and *n* is the length of `sorted`.
	@discardableResult fileprivate func shiftRemove(indices sorted: [Int]) -> [Int] {
		guard sorted.count > 0 else {
			return []
		}
		var listOfDeletes: [Int] = []
		let min = sorted.first!, max = sorted.last!
		for (i, val) in projection.enumerated().reversed() {
			guard val >= min else { continue }
			if val > max {
				projection[i] -= sorted.count
			} else {
				let c = sorted.binTreeIndex(of: val, compare: (<))!
				if val == sorted[c] {
					projection.remove(at: i)
					listOfDeletes.append(i)
				} else {
					projection[i] -= c
				}
			}
		}
		return listOfDeletes
	}
}
