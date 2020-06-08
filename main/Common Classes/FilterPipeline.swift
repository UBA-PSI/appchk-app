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
	
	private var cellAnimations: Bool = true
	
	required init(withDelegate: FilterPipelineDelegate) {
		delegate = withDelegate
	}
	
	/// Set a new `dataSource` query and immediately apply all filters and sorting.
	/// - Note: You must call `reload(fromSource:whenDone:)` manually!
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
		// TODO: use sorted dataSource for binary lookup?
		//       would require to shift filter and sorting indices for every new element
		guard let i = dataSource.firstIndex(where: predicate) else {
			return nil
		}
		return (i, dataSource[i])
	}
	
	/// Re-query data source and re-built filter and display sorting order.
	/// - Note: Will call `reloadData()` before `whenDone` closure is executed. But only if `cellAnimations` are enabled.
	/// - Parameter fromSource: If `false` only re-built filter and sort order
	func reload(fromSource: Bool, whenDone: @escaping () -> Void) {
		DispatchQueue.global().async {
			if fromSource {
				self.dataSource = self.sourceQuery()
			}
			self.resetFilters()
			DispatchQueue.main.sync {
				self.reloadTableCells()
				whenDone()
			}
		}
	}
	
	/// Returns the index set of either the last filter layer, or `dataSource` if no filter is set.
	fileprivate func lastLayerIndices() -> [Int] {
		pipeline.last?.selection ?? dataSource.indices.arr()
	}
	
	/// Get pipeline index of filter with given identifier
	private func indexOfFilter(_ identifier: String) -> Int? {
		pipeline.firstIndex(where: {$0.id == identifier})
	}
	
	
	// MARK: manage pipeline
	
	/// Add new filter layer. Each layer is applied upon the previous layer. Therefore, each filter
	/// can only restrict the display further. A filter cannot introduce previously removed elements.
	/// - Note: Will call `reloadData()` if `cellAnimations` are enabled.
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
			newFilter.reset(to: dataSource, previous: lastLayerIndices())
			pipeline.append(newFilter)
			display?.apply(moreRestrictive: newFilter.selection)
		}
		reloadTableCells()
	}
	
	/// Find and remove filter with given identifier. Will automatically update remaining filters and display sorting.
	/// - Note: Will call `reloadData()` if `cellAnimations` are enabled.
	func removeFilter(withId ident: String) {
		guard let i = indexOfFilter(ident) else { return }
		pipeline.remove(at: i)
		if i == pipeline.count {
			// only if we don't reset other layers we can assure `toLessRestrictive`
			display?.apply(lessRestrictive: lastLayerIndices())
		} else {
			resetFilters(startingAt: i)
		}
		reloadTableCells()
	}
	
	/// Start filter evaluation on all entries from previous filter.
	/// - Note: Will call `reloadData()` if `cellAnimations` are enabled.
	func reloadFilter(withId ident: String) {
		guard let i = indexOfFilter(ident) else { return }
		resetFilters(startingAt: i)
		reloadTableCells()
	}
	
	/// Sets the sort and display order. You should set the `delegate` to automatically update your `tableView`.
	/// - Note: Will call `reloadData()` if `cellAnimations` are enabled.
	/// - Parameter predicate: Return `true` if first element should be sorted before second element.
	func setSorting(_ predicate: @escaping PipelineSorting<T>.Predicate) {
		display = .init(predicate, pipe: self)
		reloadTableCells()
	}
	
	/// Will reverse the current display order without resorting. This is faster than setting a new sorting `predicate`.
	/// However, the `predicate` must be dynamic and support a sort order flag.
	/// - Warning: Make sure `predicate` does reflect the change or it will lead to data inconsistency!
	func reverseSorting() {
		// TODO: use semaphore to prevent concurrent edits
		display?.reverseOrder()
		reloadTableCells()
	}
	
	/// Re-built filter and display sorting order.
	/// - Parameter index: Must be: `index <= pipeline.count`
	private func resetFilters(startingAt index: Int = 0) {
		for i in index..<pipeline.count {
			pipeline[i].reset(to: dataSource, previous: (i>0)
				? pipeline[i-1].selection : dataSource.indices.arr())
		}
		// Reset is NOT less-restrictive because filters are dynamic
		// Calling reset on a filter twice may yield different results
		// E.g. if filter uses variables outside of scope (current time, search term)
		display?.reset(to: lastLayerIndices())
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
	
	/// Disable individual cell updates (update, move, insert & remove actions)
	func pauseCellAnimations(if condition: Bool = true) {
		cellAnimations = !condition && delegate?.tableView.isFrontmost ?? false
	}
	
	/// Allow individual cell updates (update, move, insert & remove actions) if tableView `isFrontmost`
	/// - Parameter reloadTable: If `true` and cell animations are disabled, perform `tableView.reloadData()`
	func continueCellAnimations(reloadTable: Bool = true) {
		if !cellAnimations {
			cellAnimations = true
			if reloadTable { delegate?.tableView.reloadData() }
		}
	}
	
	/// Reload table but only if `cellAnimations` is enabled.
	func reloadTableCells() {
		if cellAnimations { delegate?.tableView.reloadData() }
	}
	
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
		if cellAnimations { delegate?.tableView.safeInsertRow(displayIndex, with: .left) }
	}
	
	/// Update element at `index` in the original `dataSource` and immediately re-apply filter and sorting.
	/// - Parameters:
	///   - obj: Element to be added. Will overwrite previous `dataSource` object.
	///   - index: Index in the original `dataSource`
	/// - Complexity: O(*n* + (*m*+1) log *n*), where *m* is the number of filters and *n* the number of elements in each filter / projection.
	func update(_ obj: T, at index: Int) {
		let status = processPipeline(with: obj, at: index)
		guard status.changed else {
			dataSource[index] = obj // we need to update anyway
			return
		}
		let oldPos = display.deleteOld(index)
		dataSource[index] = obj
		guard status.display else {
			if cellAnimations, oldPos != -1 { delegate?.tableView.safeDeleteRows([oldPos]) }
			return
		}
		let newPos = display.insertNew(index, previousIndex: oldPos)
		if cellAnimations {
			if oldPos == -1 {
				delegate?.tableView.safeInsertRow(newPos, with: .left)
			} else {
				if oldPos == newPos {
					delegate?.tableView.safeReloadRow(oldPos)
				} else {
					delegate?.tableView.safeMoveRow(oldPos, to: newPos)
					if delegate?.tableView.isFrontmost ?? false {
						delegate?.rowNeedsUpdate(newPos)
					}
				}
			}
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
		if cellAnimations { delegate?.tableView.safeDeleteRows(indices) }
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
	
	/// Reset `selection` by copying the indices and applying the filter function
	fileprivate func reset(to dataSource: [T], previous filterIndices: [Int]) {
		selection = filterIndices
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
	
	/// Perform filter check and update internal `selection` indices.
	/// - Parameters:
	///   - obj: Object that was inserted or updated.
	///   - index: Index where the object is located after the update.
	/// - Returns: `keep` indicates whether the value should be displayed (`true`) or hidden (`false`).
	///            `idx` contains the selection filter index or `nil` if the value should be removed.
	/// - Complexity: O(log *n*), where *n* is the length of the `selection`.
	fileprivate func update(_ obj: T, at index: Int) -> (keep: Bool, idx: Int?) {
		let currentIndex = selection.binTreeIndex(of: index, compare: (<), mustExist: true)
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
	
	/// Create a fresh, already sorted, display order projection.
	/// - Parameter predicate: Return `true` if first element should be sorted before second element.
	/// - Complexity: O(*n* log *n*), where *n* is the length of the `filter`.
	required init(_ predicate: @escaping Predicate, pipe: FilterPipeline<T>) {
		comperator = { [unowned pipe] in
			predicate(pipe.dataSource[$0], pipe.dataSource[$1])
		}
		reset(to: pipe.lastLayerIndices())
	}
	
	/// - Warning: Make sure `predicate` does reflect the change. Or it will lead to data inconsistency.
	/// - Complexity: O(*n*), where *n* is the length of the `filter`.
	fileprivate func reverseOrder() {
		projection.reverse()
	}
	
	/// Replace current `projection` with new filter indices and apply sorting.
	/// - Complexity: O(*n* log *n*), where *n* is the length of the `filter`.
	fileprivate func reset(to filterIndices: [Int]) {
		projection = filterIndices.sorted(by: comperator)
	}
	
	/// After adding a new layer of filtering the new layer can only restrict the display even further.
	/// Therefore, indices that were removed in the last layer will be removed from the projection too.
	/// - Complexity: O(*m* log *n*), where *m* is the length of the `projection` and *n* the length of the `filter`.
	fileprivate func apply(moreRestrictive filterIndices: [Int]) {
		projection.removeAll { !filterIndices.binTreeExists($0, compare: (<)) }
	}
	
	/// After removing a layer of filtering the previous layers are less restrictive and thus contain more indices.
	/// Therefore, the difference between both index sets will be inserted into the projection.
	/// - Complexity: O(*m* log *n*), where *m* is the difference to the previous layer and *n* is the length of the `projection`.
	fileprivate func apply(lessRestrictive filterIndices: [Int]) {
		for x in filterIndices.difference(toSubset: projection.sorted(), compare: (<)) {
			insertNew(x)
		}
	}
	
	/// Add new element and automatically sort according to predicate
	/// - Parameters:
	///   - index: Index of the element position in the original `dataSource`
	///   - prev: If greater than `0`, try re-insert at the same position.
	/// - Returns: Index in the projection
	/// - Complexity: O(log *n*), where *n* is the length of the `projection`.
	@discardableResult fileprivate func insertNew(_ index: Int, previousIndex prev: Int = -1) -> Int {
		if prev >= 0, prev < projection.count {
			if (prev == 0 || !comperator(index, projection[prev - 1])), !comperator(projection[prev], index) {
				// If element can be inserted at the same position without resorting, do that
				projection.insert(index, at: prev)
				return prev
			}
		}
		return projection.binTreeInsert(index, compare: comperator)
	}
	
	/// Remove element from projection
	/// - Parameter index: Index of the element position in the original `dataSource`
	/// - Returns: Index in the projection or `-1` if element did not exist
	/// - Complexity: O(*n*), where *n* is the length of the `projection`.
	fileprivate func deleteOld(_ index: Int) -> Int {
		guard let i = projection.firstIndex(of: index) else {
			return -1
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
