import UIKit

class TVCRecordingDetails: UITableViewController, EditActionsRemove {
	var record: Recording!
	var noResults: Bool = false
	private lazy var isLongRecording: Bool = record.isLongTerm
	
	@IBOutlet private var shareButton: UIBarButtonItem!
	
	private var showRaw: Bool = false
	/// Sorted by `ts` in ascending order (oldest first)
	private lazy var dataSourceRaw: [DomainTsPair] = {
		let list = RecordingsDB.details(record)
		noResults = list.count == 0
		shareButton.isEnabled = !noResults
		return list
	}()
	/// Sorted by `count` (descending), then alphabetically
	private lazy var dataSourceSum: [(domain: String, count: Int)] = {
		var result: [String:Int] = [:]
		for x in dataSourceRaw {
			result[x.domain] = (result[x.domain] ?? 0) + 1 // group and count
		}
		return result.map{$0}.sorted {
			$0.count > $1.count || $0.count == $1.count && $0.domain < $1.domain
		}
	}()
	
	override func viewDidLoad() {
		title = record.title ?? record.fallbackTitle
		NotifyRecordingChanged.observe(call: #selector(recordingDidChange(_:)), on: self)
	}
	
	@objc private func recordingDidChange(_ notification: Notification) {
		let (rec, deleted) = notification.object as! (Recording, Bool)
		if rec.id == record.id, !deleted {
			record = rec // almost exclusively when 'shared' is set true
		}
	}
	
	@IBAction private func toggleDisplayStyle(_ sender: UIBarButtonItem) {
		showRaw = !showRaw
		sender.image = UIImage(named: showRaw ? "line-collapse" : "line-expand")
		tableView.reloadData()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let tgt = segue.destination as? TVCShareRecording {
			tgt.record = self.record
		}
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
		max(1, showRaw ? dataSourceRaw.count : dataSourceSum.count)
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: UITableViewCell
		if noResults {
			cell = tableView.dequeueReusableCell(withIdentifier: "RecordNoResultsCell")!
			cell.textLabel?.text = "– empty recording –"
		} else if showRaw {
			let x = dataSourceRaw[indexPath.row]
			if isLongRecording {
				cell = tableView.dequeueReusableCell(withIdentifier: "RecordDetailLongCell")!
				cell.textLabel?.text = x.domain
				cell.detailTextLabel?.text = DateFormat.seconds(x.ts)
			} else {
				cell = tableView.dequeueReusableCell(withIdentifier: "RecordDetailShortCell")!
				cell.textLabel?.text = "+ " + TimeFormat.from(x.ts - record.start)
				cell.detailTextLabel?.text = x.domain
			}
		} else {
			let x = dataSourceSum[indexPath.row]
			cell = tableView.dequeueReusableCell(withIdentifier: "RecordDetailCountedCell")!
			cell.textLabel?.text = x.domain
			cell.detailTextLabel?.text = "\(x.count)×"
		}
		return cell
	}
	
	
	// MARK: - Editing
	
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		noResults ? nil : getRowActionsIOS9(indexPath, tableView)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		noResults ? nil : getRowActionsIOS11(indexPath)
	}
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		if showRaw {
			let x = dataSourceRaw[index.row]
			if RecordingsDB.deleteSingle(record, domain: x.domain, ts: x.ts) {
				if let i = dataSourceSum.firstIndex(where: { $0.domain == x.domain }) {
					dataSourceSum[i].count -= 1
					if dataSourceSum[i].count == 0 {
						dataSourceSum.remove(at: i)
					}
				}
				dataSourceRaw.remove(at: index.row)
				tableView.deleteRows(at: [index], with: .automatic)
			}
		} else {
			let dom = dataSourceSum[index.row].domain
			if RecordingsDB.deleteDetails(record, domain: dom) {
				dataSourceRaw.removeAll { $0.domain == dom }
				dataSourceSum.remove(at: index.row)
				tableView.deleteRows(at: [index], with: .automatic)
			}
		}
		noResults = dataSourceRaw.count == 0
		shareButton.isEnabled = !noResults
		return true
	}
	
	
	// MARK: - Tap to Copy
	
	private var cellMenu = TableCellTapMenu()
	private var copyDomain: String? = nil
		
	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		if noResults { return nil }
		let buttons = [
			UIMenuItem(title: "All requests", action: #selector(openInLogs)),
			UIMenuItem(title: "Co-Occurrence", action: #selector(openCoOccurrence))
		]
		if cellMenu.start(tableView, indexPath, items: buttons) {
			if showRaw {
				copyDomain = cellMenu.getSelected(dataSourceRaw)?.domain
			} else {
				copyDomain = cellMenu.getSelected(dataSourceSum)?.domain
			}
			self.becomeFirstResponder()
		}
		return nil
	}
	
	override var canBecomeFirstResponder: Bool { true }
	
	override func copy(_ sender: Any?) {
		if let dom = copyDomain {
			UIPasteboard.general.string = dom
		}
		cellMenu.reset()
		copyDomain = nil
	}
	
	@objc private func openInLogs() {
		if let dom = copyDomain, let req = (tabBarController as? TBCMain)?.openTab(0) as? TVCDomains {
			VCDateFilter.disableFilter()
			req.pushOpen(domain: dom)
		}
		cellMenu.reset()
		copyDomain = nil
	}
	
	@objc private func openCoOccurrence() {
		if let dom = copyDomain {
			present(VCCoOccurrence.make(dom), animated: true)
		}
		cellMenu.reset()
		copyDomain = nil
	}
}
