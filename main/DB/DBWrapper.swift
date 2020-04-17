import UIKit

let DBWrp = DBWrapper()
fileprivate var AppDB: SQLiteDatabase? { get { try? SQLiteDatabase.open() } }

class DBWrapper {
	private var latestModification: Timestamp = 0
	private var dataA: [GroupedDomain] = [] // Domains
	private var dataB: [[GroupedDomain]] = [] // Hosts
	private var dataF: [String : FilterOptions] = [:] // Filters
	private let Q = DispatchQueue(label: "de.uni-bamberg.psi.AppCheck.db-wrapper-queue", attributes: .concurrent)
	
	// auto update rows callback
	var currentlyOpenParent: String?
	weak var dataA_delegate: IncrementalDataSourceUpdate?
	weak var dataB_delegate: IncrementalDataSourceUpdate?
	func dataB_delegate(_ parent: String) -> IncrementalDataSourceUpdate? {
		(currentlyOpenParent == parent) ? dataB_delegate : nil
	}
	
	
	// MARK: - Data Source Getter
	
	func listOfDomains() -> [GroupedDomain] {
		Q.sync() { dataA }
	}
	
	func listOfHosts(_ parent: String) -> [GroupedDomain] {
		Q.sync() { dataB[ifExist: dataA_index(of: parent)] ?? [] }
	}
	
	func dataF_list(_ filter: FilterOptions) -> [String] {
		Q.sync() { dataF.compactMap { $1.contains(filter) ? $0 : nil } }.sorted()
	}
	
	func dataF_counts() -> (blocked: Int, ignored: Int) {
		Q.sync() { dataF.reduce((0, 0)) {
			($0.0 + ($1.1.contains(.blocked) ? 1 : 0),
			 $0.1 + ($1.1.contains(.ignored) ? 1 : 0)) }}
	}
	
	func listOfTimes(_ domain: String?) -> [(Timestamp, Bool)] {
		guard let domain = domain else { return [] }
		return AppDB?.timesForDomain(domain)?.reversed() ?? []
	}
	
	
	// MARK: - Init
	
	func initContentOfDB() {
		QLog.Debug("SQLite path: \(URL.internalDB())")
		DispatchQueue.global().async {
#if IOS_SIMULATOR
			self.generateTestData()
			DispatchQueue.main.async {
				// dont know why main queue is needed, wont start otherwise
				Timer.repeating(2, call: #selector(self.insertRandomEntry), on: self)
			}
#endif
			self.dataF_init()
			self.dataAB_init()
			self.autoSyncTimer_init()
		}
	}
	
	private func dataF_init() {
		let list = AppDB?.loadFilters() ?? [:]
		Q.async(flags: .barrier) {
			self.dataF = list
			NotifyFilterChanged.postAsyncMain()
		}
	}
	
	private func dataAB_init() {
		let list = AppDB?.domainList()
		Q.async(flags: .barrier) {
			self.dataA = []
			self.dataB = []
			self.latestModification = 0
			if let allDomains = list {
				for (parent, parts) in self.groupBySubdomains(allDomains) {
					self.dataA.append(parent)
					self.dataB.append(parts)
					self.latestModification = max(parent.lastModified, self.latestModification)
				}
			}
			NotifyLogHistoryReset.postAsyncMain()
		}
	}
	
	/// Auto sync new logs every 7 seconds.
	private func autoSyncTimer_init() {
		Q.async() { // using Q to start timer only after init data A,B,F
			DispatchQueue.main.async {
				// dont know why main queue is needed, wont start otherwise
				Timer.repeating(7, call: #selector(self.syncNewestLogs), on: self)
			}
		}
	}
	
	
	// MARK: - Partial Update History
	
	@objc private func syncNewestLogs() {
		//QLog.Debug("\(#function)")
#if !IOS_SIMULATOR
		guard currentVPNState == .on else { return }
#endif
		guard let res = AppDB?.domainList(since: latestModification), res.count > 0 else {
			return
		}
		QLog.Info("auto sync \(res.count) new logs")
		Q.async(flags: .barrier) {
			var c = 0
			for (parent, parts) in self.groupBySubdomains(res) {
				if let i = self.dataA_index(of: parent.domain) {
					self.mergeExistingParts(parent.domain, at: i, newChildren: parts)
					
					let merged = parent + self.dataA.remove(at: i)
					self.dataA.insert(merged, at: c)
					self.dataB.insert(self.dataB.remove(at: i), at: c)
					self.dataA_delegate?.moveRow(merged, from: i, to: c)
				} else {
					self.dataA.insert(parent, at: c)
					self.dataB.insert(parts, at: c)
					self.dataA_delegate?.insertRow(parent, at: c)
				}
				c += 1
				self.latestModification = max(parent.lastModified, self.latestModification)
			}
		}
	}
	
	private func mergeExistingParts(_ dom: String, at index: Int, newChildren: [GroupedDomain]) {
		let tvc = dataB_delegate(dom)
		var i = 0
		for child in newChildren {
			if let u = dataB[index].firstIndex(where: { $0.domain == child.domain }) {
				let merged = child + dataB[index].remove(at: u)
				dataB[index].insert(merged, at: i)
				tvc?.moveRow(merged, from: u, to: i)
			} else {
				dataB[index].insert(child, at: i)
				tvc?.insertRow(child, at: i)
			}
			i += 1
		}
	}
	
	
	// MARK: - Delete History
	
	func deleteHistory() {
		DispatchQueue.global().async {
			try? AppDB?.destroyContent()
			AppDB?.vacuum()
			self.dataAB_init()
		}
	}
	
	func deleteHistory(domain: String, since ts: Timestamp) {
		DispatchQueue.global().async {
			let modified = (try? AppDB?.deleteRows(matching: domain, since: ts)) ?? 0
			guard modified > 0 else {
				return // nothing has changed
			}
			AppDB?.vacuum()
			self.Q.async(flags: .barrier) {
				guard let index = self.dataA_index(of: domain) else {
					return // nothing has changed
				}
				let parentDom = self.dataA[index].domain
				guard let list = AppDB?.domainList(matching: parentDom), list.count > 0 else {
					self.dataA.remove(at: index)
					self.dataB.remove(at: index)
					self.dataA_delegate?.deleteRow(at: index)
					self.dataB_delegate(parentDom)?.replaceData(with: [])
					return // nothing left, after deleting matching rows
				}
				// else: incremental update, replace whole list
				self.dataA[index] = list.merge(parentDom, options: self.dataF[parentDom])
				self.dataA_delegate?.replaceRow(self.dataA[index], at: index)
				self.dataB[index].removeAll()
				for var child in list {
					child.options = self.dataF[child.domain]
					self.dataB[index].append(child)
				}
				self.dataB_delegate(parentDom)?.replaceData(with: self.dataB[index])
			}
		}
	}
	
	
	// MARK: - Partial Update Filter
	
	func updateFilter(_ domain: String, add: FilterOptions) {
		updateFilter(domain, set: (dataF[domain] ?? FilterOptions()).union(add))
	}
	
	func updateFilter(_ domain: String, remove: FilterOptions) {
		updateFilter(domain, set: dataF[domain]?.subtracting(remove))
	}
	
	/// - Parameters:
	///   - set: Remove a filter with `nil` or `.none`
	private func updateFilter(_ domain: String, set: FilterOptions?) {
		AppDB?.setFilter(domain, set)
		Q.async(flags: .barrier) {
			self.dataF[domain] = set
			if let i = self.dataA_index(of: domain) {
				if domain == self.dataA[i].domain {
					self.dataA[i].options = (set == FilterOptions.none) ? nil : set
					self.dataA_delegate?.replaceRow(self.dataA[i], at: i)
				}
				if let u = self.dataB[i].firstIndex(where: { $0.domain == domain }) {
					self.dataB[i][u].options = (set == FilterOptions.none) ? nil : set
					self.dataB_delegate(self.dataA[i].domain)?.replaceRow(self.dataB[i][u], at: u)
				}
			}
			NotifyFilterChanged.postAsyncMain()
		}
	}
	
	
	// MARK: - Recordings
	
	func listOfRecordings() -> [Recording] { AppDB?.allRecordings() ?? [] }
	func recordingGetCurrent() -> Recording? { AppDB?.ongoingRecording() }
	func recordingStartNew() -> Recording? { try? AppDB?.startNewRecording() }
	
	func recordingStop(_ r: inout Recording) { AppDB?.stopRecording(&r) }
	func recordingPersist(_ r: Recording) { AppDB?.persistRecordingLogs(r) }
	func recordingDetails(_ r: Recording) -> [RecordLog] { AppDB?.getRecordingsLogs(r) ?? [] }
	
	func recordingUpdate(_ r: Recording) {
		AppDB?.updateRecording(r)
		NotifyRecordingChanged.post((r, false))
	}
	
	func recordingDelete(_ r: Recording) {
		if (try? AppDB?.deleteRecording(r)) == true {
			NotifyRecordingChanged.post((r, true))
		}
	}
	
	func recordingDeleteDetails(_ r: Recording, domain: String?) -> Bool {
		((try? AppDB?.deleteRecordingLogs(r.id, matchingDomain: domain)) ?? 0) > 0
	}
	
	
	// MARK: - Helper methods
	
	private func dataA_index(of domain: String) -> Int? {
		dataA.firstIndex { domain.isSubdomain(of: $0.domain) }
	}
	
	private func groupBySubdomains(_ allDomains: [GroupedDomain]) -> [(parent: GroupedDomain, parts: [GroupedDomain])] {
		var i: Int = 0
		var indexOf: [String: Int] = [:]
		var res: [(domain: String, list: [GroupedDomain])] = []
		for var x in allDomains {
			let domain = x.domain.splitDomainAndHost().domain
			x.options = dataF[x.domain]
			if let y = indexOf[domain] {
				res[y].list.append(x)
			} else {
				res.append((domain, [x]))
				indexOf[domain] = i
				i += 1
			}
		}
		return res.map { ($1.merge($0, options: self.dataF[$0]), $1) }
	}
}


// MARK: - Test Data

extension DBWrapper {
	private func generateTestData() {
		guard let db = AppDB else { return }
		let deleted = (try? db.deleteRows(matching: "test.com")) ?? 0
		QLog.Debug("Deleting \(deleted) rows matching 'test.com'")
		
		QLog.Debug("Writing 33 test logs")
		try? db.insertDNSQuery("keeptest.com", blocked: false)
		for _ in 1...4 { try? db.insertDNSQuery("test.com", blocked: false) }
		for _ in 1...7 { try? db.insertDNSQuery("i.test.com", blocked: false) }
		for i in 1...8 { try? db.insertDNSQuery("b.test.com", blocked: i>5) }
		for i in 1...13 { try? db.insertDNSQuery("bi.test.com", blocked: i%2==0) }
		
		QLog.Debug("Creating 4 filters")
		db.setFilter("b.test.com", .blocked)
		db.setFilter("i.test.com", .ignored)
		db.setFilter("bi.test.com", [.blocked, .ignored])
		
		QLog.Debug("Done")
	}
	
	@objc private func insertRandomEntry() {
		//QLog.Debug("Inserting 1 periodic log entry")
		try? AppDB?.insertDNSQuery("\(arc4random() % 5).count.test.com", blocked: true)
	}
}
