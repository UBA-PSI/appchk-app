import UIKit

// TODO: (count > x) filter

class VCDateFilter: UIViewController, UIGestureRecognizerDelegate {
	
	@IBOutlet private var segmentControl: UISegmentedControl!
	@IBOutlet private var sectionTitle: UILabel!
	
	// entries no older than
	@IBOutlet private var durationView: UIView!
	@IBOutlet private var durationSlider: UISlider!
	@IBOutlet private var durationLabel: UILabel!
	private let durationTimes = [0, 1, 20, 60, 360, 720, 1440, 2880, 4320, 10080]
	
	// entries within range
	@IBOutlet private var rangeView: UIView!
	@IBOutlet private var buttonRangeStart: UIButton!
	@IBOutlet private var buttonRangeEnd: UIButton!
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		segmentControl.selectedSegmentIndex = (Pref.DateFilter.Kind == .ABRange ? 1 : 0)
		didChangeSegment(segmentControl)
		segmentControl.setEnabled(false, forSegmentAt: 1) // TODO: until range filter is ready
		
		durationSlider.tag = -1 // otherwise wont update because `tag == 0`
		durationSlider.value = Float(durationTimes.firstIndex(of: Pref.DateFilter.LastXMin) ?? 0) / 9
		durationSliderChanged(durationSlider)
		
		var a = Timestamp(4).asDateTime() // TODO: load from preferences
		var b = Timestamp.now().asDateTime()
		a.removeLast(3) // remove seconds
		b.removeLast(3)
		buttonRangeStart.setTitle(a, for: .normal)
		buttonRangeEnd.setTitle(b, for: .normal)
	}
	
	@IBAction private func didChangeSegment(_ sender: UISegmentedControl) {
		durationView.isHidden = (sender.selectedSegmentIndex != 0)
		rangeView.isHidden = (sender.selectedSegmentIndex != 1)
		switch sender.selectedSegmentIndex {
		case 0: sectionTitle.text = "Show entries no older than"
		case 1: sectionTitle.text = "Show entries within range"
		default: break
		}
	}
	
	@IBAction private func durationSliderChanged(_ sender: UISlider) {
		let i = Int((sender.value + (0.499/9)) * 9) // mid-value-switch
		guard i >= 0, i <= 9 else { return }
		sender.value = Float(i) / 9
		if sender.tag != durationTimes[i] {
			sender.tag = durationTimes[i]
			durationLabel.text = (sender.tag == 0 ? "Off" : TimeFormat.short(minutes: sender.tag))
		}
	}
	
	@IBAction private func didTapRangeButton(_ sender: UIButton) {
		// TODO: show date picker
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		if gestureRecognizer.view == touch.view {
			let newXMin = durationSlider.tag
			let newKind: DateFilterKind
			if segmentControl.selectedSegmentIndex == 1 {
				newKind = .ABRange
			} else if newXMin > 0 {
				newKind = .LastXMin
			} else {
				newKind = .Off
			}
			if Pref.DateFilter.Kind != newKind || Pref.DateFilter.LastXMin != newXMin {
				Pref.DateFilter.Kind = newKind
				Pref.DateFilter.LastXMin = newXMin
				NotifyDateFilterChanged.post()
			}
			dismiss(animated: true)
		}
		return false
	}
}


// MARK: White Triangle Popup Arrow

@IBDesignable
class PopupTriangle: UIView {
	@IBInspectable var rotation: CGFloat = 0
	@IBInspectable var color: UIColor = .black
	
	override func draw(_ rect: CGRect) {
		guard let c = UIGraphicsGetCurrentContext() else { return }
		let w = rect.width, h = rect.height
		switch rotation {
		case 90: // right
			c.lineFromTo(x1: 0, y1: 0, x2: w, y2: h/2)
			c.addLine(to: CGPoint(x: 0, y: h))
		case 180: // bottom
			c.lineFromTo(x1: w, y1: 0, x2: w/2, y2: h)
			c.addLine(to: CGPoint(x: 0, y: 0))
		case 270: // left
			c.lineFromTo(x1: w, y1: h, x2: 0, y2: h/2)
			c.addLine(to: CGPoint(x: w, y: 0))
		default: // top
			c.lineFromTo(x1: 0, y1: h, x2: w/2, y2: 0)
			c.addLine(to: CGPoint(x: w, y: h))
		}
		c.closePath()
		c.setFillColor(color.cgColor)
		c.fillPath()
	}
}
