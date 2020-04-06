import UIKit

class TVCRecordingDetails: UITableViewController {
	var record: Recording!
	private var dataSource: [(domain: String, count: Int)] = [
		("apple.com", 3),
		("cdn.apple.com", 1)
	]
	
	override func viewDidLoad() {
		title = record.title ?? record.fallbackTitle
		// TODO: load db entries
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
}
