import UIKit

class VCRecordings: UIViewController, UINavigationControllerDelegate {
	private var currentRecording: Recording?
	private var recordingTimer: Timer?
	
	@IBOutlet private var timeLabel: UILabel!
	@IBOutlet private var startButton: UIButton!
	@IBOutlet private var startNewRecView: UIView!
	private var prevRecController: UINavigationController!
	
	override func viewDidLoad() {
		prevRecController = (children.first as! UINavigationController)
		prevRecController.delegate = self
		// Duplicate font attributes but set monospace
		let traits = timeLabel.font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any] ?? [:]
		let weight = traits[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
		timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeLabel.font.pointSize, weight: UIFont.Weight(rawValue: weight))
		// hide timer if not running
		updateUI(setRecording: false, animated: false)
		currentRecording = DBWrp.recordingGetCurrent()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		if currentRecording != nil { startTimer(animate: false) }
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		stopTimer(animate: false)
	}
	
	func navigationController(_ navigationController: UINavigationController, willShow vc: UIViewController, animated: Bool) {
		let isRoot = (vc == navigationController.viewControllers.first)
		UIView.animate(withDuration: 0.3) {
			self.startNewRecView.isHidden = !isRoot // hide "new recording" if details open
		}
	}
	
	
	// MARK: Start New Recording
	
	@IBAction private func startRecordingButtonTapped(_ sender: UIButton) {
		if recordingTimer == nil {
			currentRecording = DBWrp.recordingStartNew()
			startTimer(animate: true)
		} else {
			stopTimer(animate: true)
			DBWrp.recordingStopAll()
			prevRecController.popToRootViewController(animated: true)
			(prevRecController.topViewController as! TVCPreviousRecords).stopRecording(currentRecording!)
			currentRecording = nil // otherwise it will restart
		}
	}
	
	private func startTimer(animate: Bool) {
		guard let r = currentRecording, r.stop == nil else {
			return
		}
		recordingTimer = Timer.repeating(0.086, call: #selector(timerCallback(_:)), on: self, userInfo: r.start.toDate())
		updateUI(setRecording: true, animated: animate)
	}
	
	@objc private func timerCallback(_ sender: Timer) {
		timeLabel.text = TimeFormat.since(sender.userInfo as! Date, millis: true)
	}
	
	private func stopTimer(animate: Bool) {
		recordingTimer?.invalidate()
		recordingTimer = nil
		updateUI(setRecording: false, animated: animate)
	}
	
	private func updateUI(setRecording: Bool, animated: Bool) {
		let title = setRecording ? "Stop Recording" : "Start New Recording"
		let color = setRecording ? UIColor.systemRed : nil
		let yT = setRecording ? 0 : -timeLabel.frame.height
		let yB = (setRecording ? 1 : 0.5) * (startButton.superview!.frame.height - startButton.frame.height)
		if !animated { // else title will flash
			startButton.titleLabel?.text = title
		}
		UIView.animate(withDuration: animated ? 0.3 : 0) {
			self.timeLabel.frame.origin.y = yT
			self.startButton.frame.origin.y = yB
			self.startButton.setTitle(title, for: .normal)
			self.startButton.setTitleColor(color, for: .normal)
		}
	}
}
