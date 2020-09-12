import UIKit

class TVCOccurrenceContext: UITableViewController {
	
	var ts: Timestamp!
	var domain: String!
	
	private let dT: Timestamp = 300 // +/- 5 minutes
	private lazy var dataSource: [DomainTsPair] = {
		let logs = AppDB?.dnsLogs(between: ts - dT, and: ts + dT) ?? []
		return [("[…]", ts - dT)] + logs.reversed() + [("[…]", ts + dT)]
	}()
	
	override func viewDidLoad() {
		navigationItem.title = "± 5 Min Context"
		super.viewDidLoad()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		jumpToTsZero()
	}
	
	@IBAction private func jumpToTsZero() {
		if let i = dataSource.firstIndex(where: { isChoosenOne($0) }) {
			tableView.scrollToRow(at: IndexPath(row: i), at: .middle, animated: true)
		}
	}
	
	private func isChoosenOne(_ obj: DomainTsPair) -> Bool {
		obj.domain == domain && obj.ts == ts
	}
	
	private func firstOrLast(_ row: Int) -> Bool {
		row == 0 || row == dataSource.count - 1
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { dataSource.count }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "OccurrenceContextCell")!
		let src = dataSource[indexPath.row]
		cell.detailTextLabel?.text = src.domain
		
		if firstOrLast(indexPath.row) {
			cell.detailTextLabel?.textColor = .sysLabel2 // same as textLabel
		} else if isChoosenOne(src) {
			cell.detailTextLabel?.textColor = .sysLink
		} else {
			cell.detailTextLabel?.textColor = .sysLabel
		}
		
		if src.ts > ts {
			cell.textLabel?.text = "+ " + TimeFormat.from(src.ts - ts)
		} else if src.ts < ts {
			cell.textLabel?.text = "− " + TimeFormat.from(ts - src.ts)
		} else {
			cell.textLabel?.text = "0"
		}
		//cell.textLabel?.text = String(format: "%+d s", src.ts - ts)
		return cell
	}
	
	
	// MARK: - Tap to Copy
	
	private var cellMenu = TableCellTapMenu()
	private var copyDomain: String? = nil
			
	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		if !firstOrLast(indexPath.row), cellMenu.start(tableView, indexPath) {
			copyDomain = cellMenu.getSelected(dataSource)?.domain
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
}
