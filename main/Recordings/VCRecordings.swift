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
		
		if !UserDefaults.standard.bool(forKey: "didShowTutorialRecordings") {
			self.perform(#selector(showTutorial), with: nil, afterDelay: 0.5)
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		if currentRecording != nil { startTimer(animate: false) }
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		stopTimer(animate: false)
	}
	
	func navigationController(_ nav: UINavigationController, willShow vc: UIViewController, animated: Bool) {
		hideNewRecording(isRootVC: (vc == nav.viewControllers.first), didShow: false)
	}
	
	func navigationController(_ nav: UINavigationController, didShow vc: UIViewController, animated: Bool) {
		hideNewRecording(isRootVC: (vc == nav.viewControllers.first), didShow: true)
	}
	
	private func hideNewRecording(isRootVC: Bool, didShow: Bool) {
		if isRootVC == didShow {
			UIView.animate(withDuration: 0.3) {
				self.startNewRecView.isHidden = !isRootVC // hide "new recording" if details open
			}
		}
	}
	
	
	// MARK: Start New Recording
	
	@IBAction private func startRecordingButtonTapped(_ sender: UIButton) {
		if recordingTimer == nil {
			currentRecording = DBWrp.recordingStartNew()
			startTimer(animate: true)
		} else {
			stopTimer(animate: true)
			DBWrp.recordingStop(&currentRecording!)
			prevRecController.popToRootViewController(animated: true)
			let editVC = (prevRecController.topViewController as! TVCPreviousRecords)
			editVC.insertAndEditRecording(currentRecording!)
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
	
	
	// MARK: Tutorial View Controller
	
	@objc private func showTutorial() {
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("What are Recordings?\n")
			.normal("\nSimilar to the default logging, recordings will intercept every request and log it for later review. " +
				"Recordings are usually 3 – 5 minutes long and cover a single application. " +
				"You can utilize recordings for App analysis or to get a ground truth for background traffic." +
				"\n\n" +
				"Optionally, you can help us by providing app specific recordings. " +
				"Together with your findings we can create a community driven privacy monitor. " +
				"The research results will help you and others avoid Apps that unnecessarily share data with third-party providers.")
		))
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("How to record?\n")
			.normal("\nBefore you begin a new recording make sure that you quit all running applications. " +
				"Tap on the 'Start Recording' button and switch to the application you'd like to inspect. " +
				"Use the App as you would normally. Try to get to all corners and functionality the App provides. " +
				"When you feel that you have captured enough content, come back to ").italic("AppCheck").normal(" and stop the recording." +
				"\n\n" +
				"Upon completion you will find your recording in the 'Previous Recordings' section. " +
				"You can review your results and remove user specific information if necessary.")
		))
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("Share results\n")
			.normal("\nThis step is completely ").bold("optional").normal(". " +
				"You can choose to share your results with us. " +
				"We can compare similar applications and suggest privacy friendly alternatives. " +
				"Together with other likeminded individuals we can increase the awareness for privacy friendly design." +
				"\n\n" +
				"Thank you very much.")
		))
		x.buttonTitleDone = "Got it"
		x.present {
			UserDefaults.standard.set(true, forKey: "didShowTutorialRecordings")
		}
	}
}
