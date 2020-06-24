import UIKit

class VCCoOccurrence: UIViewController, UITableViewDataSource {
	var fqdn: String!
	private var dataSource: [ContextAnalysisResult] = []
	
	@IBOutlet private var tableView: UITableView!
	@IBOutlet private var timeSegment: UISegmentedControl!
	private let availableTimes = [0, 5, 15, 30]
	private var selectedTime = -1 {
		didSet { logTimeDelta = log(CGFloat(max(2, selectedTime+1))) }
	}
	private var logTimeDelta: CGFloat = 1
	private var logMaxCount: CGFloat = 1
	
	override func viewDidLoad() {
		super.viewDidLoad()
		selectedTime = Pref.ContextAnalyis.CoOccurrenceTime ?? 5 // calls `didSet` and `logTimeDelta`
		timeSegment.removeAllSegments() // clear IB values
		for (i, time) in availableTimes.enumerated() {
			timeSegment.insertSegment(withTitle: TimeFormat(.abbreviated).from(seconds: time), at: i, animated: false)
			if time == selectedTime {
				timeSegment.selectedSegmentIndex = i
			}
		}
		reloadDataSource()
	}
	
	func reloadDataSource() {
		dataSource = [("Loading …", 0, 0, 0)]
		logMaxCount = 1
		tableView.reloadData()
		let domain = fqdn!
		let time = Timestamp(selectedTime)
		DispatchQueue.global().async { [weak self] in
			guard let db = AppDB, let times = db.dnsLogsUniqTs(domain), times.count > 0 else {
				return // should never happen, or what did you tap then?
			}
			guard let result = db.contextAnalysis(coOccurrence: times, plusMinus: time, exclude: domain) else {
				return
			}
			self?.dataSource = result
			self?.logMaxCount = log(CGFloat(result.reduce(0) { max($0, $1.count)  }))
			DispatchQueue.main.sync { [weak self] in
				self?.tableView.reloadData()
			}
		}
	}
	
	@IBAction func didChangeTime(_ sender: UISegmentedControl) {
		selectedTime = availableTimes[sender.selectedSegmentIndex]
		Pref.ContextAnalyis.CoOccurrenceTime = selectedTime
		reloadDataSource()
	}
	
	@IBAction func didClose(_ sender: UIBarButtonItem) {
		dismiss(animated: true)
	}
	
	
	// MARK: - Table View Data Source
	
	func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int {
		dataSource.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "CoOccurrenceCell") as! CoOccurrenceCell
		let src = dataSource[indexPath.row]
		cell.title.text = src.domain
		cell.rank.text = "\(indexPath.row + 1)."
		cell.count.text = "\(src.count)"
		cell.avgdiff.text = String(format: "%.2fs", src.avg)
		
		cell.countMeter.percent = (log(CGFloat(src.count)) / logMaxCount)
		cell.avgdiffMeter.percent = 1 - (log(CGFloat(src.avg + 1)) / logTimeDelta)
		return cell
	}
}

class CoOccurrenceCell: UITableViewCell {
	@IBOutlet var title: UILabel!
	@IBOutlet var rank: TagLabel!
	@IBOutlet var count: TagLabel!
	@IBOutlet var avgdiff: TagLabel!
	@IBOutlet var countMeter: MeterBar!
	@IBOutlet var avgdiffMeter: MeterBar!
}
