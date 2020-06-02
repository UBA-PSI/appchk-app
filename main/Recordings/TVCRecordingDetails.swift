import UIKit

class TVCRecordingDetails: UITableViewController, EditActionsRemove {
	var record: Recording!
	private var dataSource: [RecordLog]!
	
	override func viewDidLoad() {
		title = record.title ?? record.fallbackTitle
		dataSource = RecordingsDB.details(record)
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PreviousRecordDetailCell")!
		let x = dataSource[indexPath.row]
		cell.textLabel?.text = x.domain
		cell.detailTextLabel?.text = "\(x.count)"
		return cell
	}
	
	
	// MARK: - Editing
	
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		getRowActionsIOS9(indexPath)
	}
	@available(iOS 11.0, *)
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		getRowActionsIOS11(indexPath)
	}
	
	func editableRowCallback(_ index: IndexPath, _ action: RowAction, _ userInfo: Any?) -> Bool {
		if RecordingsDB.deleteDetails(record, domain: dataSource[index.row].domain) {
			dataSource.remove(at: index.row)
			tableView.deleteRows(at: [index], with: .automatic)
		}
		return true
	}
}
