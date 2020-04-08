import UIKit

class TVCRecordingDetails: UITableViewController, EditActionsRemove {
	var record: Recording!
	private var dataSource: [RecordLog]!
	
	override func viewDidLoad() {
		title = record.title ?? record.fallbackTitle
		dataSource = DBWrp.recordingDetails(record)
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PreviousRecordDetailCell")!
		let x = dataSource[indexPath.row]
		cell.textLabel?.text = x.domain
		cell.detailTextLabel?.text = "\(x.count)"
		return cell
	}
	
	
	// MARK: - Editing
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		if DBWrp.recordingDeleteDetails(record, domain: self.dataSource[index.row].domain) {
			self.dataSource.remove(at: index.row)
			self.tableView.deleteRows(at: [index], with: .automatic)
		}
		return true
	}
}
