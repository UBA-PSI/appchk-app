import UIKit

// TODO: (count > x) filter

class VCDateFilter: UIViewController, UIGestureRecognizerDelegate {
	
	@IBOutlet private var filterBy: UISegmentedControl!
	
	// entries no older than
	@IBOutlet private var durationTitle: UILabel!
	@IBOutlet private var durationView: UIView!
	@IBOutlet private var durationSlider: UISlider!
	@IBOutlet private var durationLabel: UILabel!
	private let durationTimes = [0, 1, 20, 60, 360, 720, 1440, 2880, 4320, 10080]
	
	// entries within range
	@IBOutlet private var rangeTitle: UILabel!
	@IBOutlet private var rangeView: UIView!
	@IBOutlet private var buttonRangeStart: UIButton!
	@IBOutlet private var buttonRangeEnd: UIButton!
	private lazy var tsRangeA: Timestamp = Pref.DateFilter.RangeA ?? AppDB?.dnsLogsMinDate() ?? .now()
	private lazy var tsRangeB: Timestamp = Pref.DateFilter.RangeB ?? .now()
	
	// order by
	@IBOutlet private var orderbyType: UISegmentedControl!
	@IBOutlet private var orderbyAsc: UISegmentedControl!
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		filterBy.selectedSegmentIndex = (Pref.DateFilter.Kind == .ABRange ? 1 : 0)
		didChangeFilterBy(filterBy)
		
		durationSlider.tag = -1 // otherwise wont update because `tag == 0`
		durationSlider.value = Float(durationTimes.firstIndex(of: Pref.DateFilter.LastXMin) ?? 0) / 9
		durationSliderChanged(durationSlider)
		
		buttonRangeStart.setTitle(DateFormat.minutes(tsRangeA), for: .normal)
		buttonRangeEnd.setTitle(DateFormat.minutes(tsRangeB), for: .normal)
		
		orderbyType.selectedSegmentIndex = Pref.DateFilter.OrderBy.rawValue
		orderbyAsc.selectedSegmentIndex = (Pref.DateFilter.OrderAsc ? 0 : 1)
	}
	
	@IBAction private func didChangeFilterBy(_ sender: UISegmentedControl) {
		let firstSelected = (sender.selectedSegmentIndex == 0)
		durationTitle.isHidden = !firstSelected
		durationView.isHidden = !firstSelected
		rangeTitle.isHidden = firstSelected
		rangeView.isHidden = firstSelected
	}
	
	@IBAction private func durationSliderChanged(_ sender: UISlider) {
		let i = Int((sender.value + (0.499/9)) * 9) // mid-value-switch
		guard i >= 0, i <= 9 else { return }
		sender.value = Float(i) / 9
		if sender.tag != durationTimes[i] {
			sender.tag = durationTimes[i]
			durationLabel.text = (sender.tag == 0 ? "Off" : TimeFormat(.short).from(minutes: sender.tag))
		}
	}
	
	@IBAction private func didTapRangeButton(_ sender: UIButton) {
		let flag = (sender == buttonRangeStart)
		let oldDate = flag ? Date(self.tsRangeA) : Date(self.tsRangeB)
		DatePickerAlert(initial: oldDate).present(in: self) { (selected: Date) in
			var ts = selected.timestamp
			ts -= ts % 60 // remove seconds
			// if one of these is greater than the other, adjust the latter too.
			if flag || self.tsRangeA > ts {
				self.tsRangeA = ts // lower end of minute
				self.buttonRangeStart.setTitle(DateFormat.minutes(ts), for: .normal)
			}
			if !flag || ts > self.tsRangeB {
				self.tsRangeB = ts + 59 // upper end of minute
				self.buttonRangeEnd.setTitle(DateFormat.minutes(ts + 59), for: .normal)
			}
		}
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		if gestureRecognizer.view === touch.view {
			saveSettings()
			dismiss(animated: true)
		}
		return false
	}
	
	private func saveSettings() {
		let newXMin = durationSlider.tag
		let filterType: DateFilterKind
		let orderType: DateFilterOrderBy
		
		switch filterBy.selectedSegmentIndex {
		case 0: filterType = (newXMin > 0) ? .LastXMin : .Off
		case 1: filterType = .ABRange
		default: preconditionFailure()
		}
		switch orderbyType.selectedSegmentIndex {
		case 0: orderType = .Date
		case 1: orderType = .Name
		case 2: orderType = .Count
		default: preconditionFailure()
		}
		let a = Pref.DateFilter.OrderBy <-? orderType
		let b = Pref.DateFilter.OrderAsc <-? (orderbyAsc.selectedSegmentIndex == 0)
		if a || b {
			NotifySortOrderChanged.post()
		}
		let c = Pref.DateFilter.Kind <-? filterType
		let d = Pref.DateFilter.LastXMin <-? newXMin
		let e = Pref.DateFilter.RangeA <-? (filterType == .ABRange ? tsRangeA : nil)
		let f = Pref.DateFilter.RangeB <-? (filterType == .ABRange ? tsRangeB : nil)
		if c || d || e || f {
			NotifyDateFilterChanged.post()
		}
	}
}
