import UIKit

class TVCRecordingDetails: UITableViewController, EditActionsRemove {
	var record: Recording!
	private lazy var isLongRecording: Bool = record.isLongTerm
	
	private var showRaw: Bool = false
	/// Sorted by `ts` in ascending order (oldest first)
	private lazy var dataSourceRaw: [DomainTsPair] = RecordingsDB.details(record)
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
	}
	
	@IBAction private func toggleDisplayStyle(_ sender: UIBarButtonItem) {
		showRaw = !showRaw
		sender.image = UIImage(named: showRaw ? "line-collapse" : "line-expand")
		tableView.reloadData()
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
		showRaw ? dataSourceRaw.count : dataSourceSum.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: UITableViewCell
		if showRaw {
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
		getRowActionsIOS9(indexPath, tableView)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
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
		return true
	}
}
