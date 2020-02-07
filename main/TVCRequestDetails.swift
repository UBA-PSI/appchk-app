import UIKit

class TVCRequestDetails: UITableViewController {

	public var dataSource: [Int64] = []
	private let dateFormatter = DateFormatter()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		dateFormatter.dateFormat = "yyyy-MM-dd  HH:mm:ss"
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "RequestDetailCell")!
		let intVal = dataSource[indexPath.row]
		let date = Date.init(timeIntervalSince1970: Double(intVal))
		cell.textLabel?.text = dateFormatter.string(from: date)
		return cell
	}
}
