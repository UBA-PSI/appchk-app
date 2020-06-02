import Foundation

enum DomainFilter {
	static private var data: [String: FilterOptions] = {
		AppDB?.loadFilters() ?? [:]
	}()
	
	/// Get filter with given `domain` name
	@inline(__always) static subscript(_ domain: String) -> FilterOptions? {
		data[domain]
	}
	
	/// Update local memory object by loading values from persistent db.
	/// - Note: Will trigger `NotifyDNSFilterChanged` notification.
	static func reload() {
		data = AppDB?.loadFilters() ?? [:]
		NotifyDNSFilterChanged.post()
	}
	
	/// Get list of domains (sorted by name) which do contain the given filter
	static func list(where matching: FilterOptions) -> [String] {
		data.compactMap { $1.contains(matching) ? $0 : nil }.sorted()
	}
	
	/// Get total number of blocked and ignored domains. Shown in settings overview.
	static func counts() -> (blocked: Int, ignored: Int) {
		data.reduce(into: (0, 0)) {
			if $1.1.contains(.blocked) { $0.0 += 1 }
			if $1.1.contains(.ignored) { $0.1 += 1 } }
	}
	
	/// Union `filter` with set.
	/// - Note: Will trigger `NotifyDNSFilterChanged` notification.
	static func update(_ domain: String, add filter: FilterOptions) {
		update(domain, set: (data[domain] ?? FilterOptions()).union(filter))
	}

	/// Subtract `filter` from set.
	/// - Note: Will trigger `NotifyDNSFilterChanged` notification.
	static func update(_ domain: String, remove filter: FilterOptions) {
		update(domain, set: data[domain]?.subtracting(filter))
	}

	/// Update persistent db, local memory object, and post notification to subscribers
	/// - Parameter set: Remove a filter with `nil` or `.none`
	static private func update(_ domain: String, set: FilterOptions?) {
		AppDB?.setFilter(domain, set)
		data[domain] = (set == FilterOptions.none) ? nil : set
		NotifyDNSFilterChanged.post(domain)
	}
}
