import UIKit

class VCCoOccurrence: UIViewController, UITableViewDataSource {
	var domainName: String!
	var isFQDN: Bool!
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
		selectedTime = Prefs.ContextAnalyis.CoOccurrenceTime ?? 5 // calls `didSet` and `logTimeDelta`
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
		let domain = domainName!
		let flag = isFQDN!
		let time = Timestamp(selectedTime)
		DispatchQueue.global().async { [weak self] in
			let temp: [ContextAnalysisResult]
			let total: Int32
			if let db = AppDB,
				let times = db.dnsLogsUniqTs(domain, isFQDN: flag), times.count > 0,
				let result = db.contextAnalysis(coOccurrence: times, plusMinus: time, exclude: domain, isFQDN: flag),
				result.count > 0
			{
				temp = result
				var sum: Int32 = 0
				for x in result { sum += x.count }
				total = sum // if statement guarantees >= 1
			} else {
				temp = []
				total = 1
			}
			DispatchQueue.main.sync { [weak self] in
				self?.dataSource = temp
				self?.logMaxCount = log(CGFloat(total + 1))
				self?.tableView.reloadData()
			}
		}
	}
	
	@IBAction func didChangeTime(_ sender: UISegmentedControl) {
		selectedTime = availableTimes[sender.selectedSegmentIndex]
		Prefs.ContextAnalyis.CoOccurrenceTime = selectedTime
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
		
		// log percentage of total co-occurrence count + 1 (min: log(2))
		cell.countMeter.percent = (log(CGFloat(src.count + 1)) / logMaxCount)
		// log percentage of selected time window (0s/5s/15s/30s) + 1 (min: log(2))
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


// MARK: - Tutorial Screen

extension VCCoOccurrence {
	
	@IBAction func showInfoScreen() {
		let sampleCell: UIImage = {
			let cell = tableView.dequeueReusableCell(withIdentifier: "CoOccurrenceCell") as! CoOccurrenceCell
			cell.title.text = "example.org"
			cell.rank.text = "9."
			cell.count.text = "14"
			cell.avgdiff.text = String(format: "%.2fs", 0.71)
			cell.countMeter.percent = 0.35
			cell.avgdiffMeter.percent = 0.95
			
			// Bug: Sometimes dequeue will return a "broken" hidden cell.
			//      It can't be set visible and thus can't render an image.
			//      Funnily `cell.contentView` can rendered.
			let theView = cell.isHidden ? cell.contentView : cell
			
			// resize view to fit into tutorial sheet
			let minWidth = TutorialSheet.verticalWidth - 10 //-> 2 * textContainer.lineFragmentPadding
			theView.frame.size = theView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
			theView.frame.size.width = min(theView.frame.size.width, minWidth)
			// set width in two steps because first call may change layoutMargins
			theView.frame.size.width += theView.layoutMargins.left + theView.layoutMargins.right
			// FIXME: In case `hidden == false`, backgroundColor will be black in Dark mode.
			theView.backgroundColor = tableView.backgroundColor
			return theView.asImage(insets: theView.layoutMargins)
		}()
		
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h3("Co-Occurrence")
			.normal(" allows you to find requests that happen often at the same time as the selected domain. " +
					"Hence it will give you a hint what Apps might be involved in the activity." +
					"\n\nHow do you interpret these results? Lets look at an example:\n\n")
			.centered(.image(sampleCell))
			.normal("\n\nThe domain ").bold("example.org").normal(" had ").bold("14").normal(" requests with an ").italic("average time divergence").normal(" of ").bold("0.71 seconds").normal(". " +
					"That is, these 14 domain calls happend, on average, less then a second before or after the original request of the selected domain." +
					"\n\nClose temporal proximity and high occurrence counts are both indicators for domain correlation. " +
					"Results are sorted by a ranking index (").bold("9.").normal(") which strikes a balance between the two. " +
					"Preferring entries with higher counts as well as low time divergence.")
			.italic("\n\nTip: ").normal("As a visual guide you can look for the colored bar beside each value. " +
					"The larger the bar, the greater the correlation.")
		))
		
		x.present(in: self)
	}
}
