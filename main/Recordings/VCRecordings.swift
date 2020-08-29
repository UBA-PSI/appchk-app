import UIKit

class VCRecordings: UIViewController, UINavigationControllerDelegate {
	private var currentRecording: Recording?
	private var recordingTimer: Timer?
	
	@IBOutlet private var headerView: UIView!
	@IBOutlet private var buttonView: UIView!
	@IBOutlet private var runningView: UIView!
	@IBOutlet private var timeLabel: UILabel!
	
	override func viewDidLoad() {
		timeLabel.font = timeLabel.font.monoSpace()
		if let ongoing = RecordingsDB.getCurrent() {
			currentRecording = ongoing
			startTimer(animate: false)
		} else { // hide timer if not running
			updateUI(setRecording: false, animated: false)
		}
		if !Prefs.DidShowTutorial.Recordings {
			self.perform(#selector(showTutorial), with: nil, afterDelay: 0.5)
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		recordingTimer?.fireDate = .distantPast
		navigationController?.setNavigationBarHidden(true, animated: animated)
		// set hidden in will appear causes UITableViewAlertForLayoutOutsideViewHierarchy
		// but otherwise navBar is visible during transition
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		recordingTimer?.fireDate = .distantFuture
		navigationController?.setNavigationBarHidden(false, animated: animated)
	}
	
	
	// MARK: Start New Recording
	
	@IBAction private func startRecording(_ sender: UISegmentedControl) {
		guard GlassVPN.state == .on else {
			AskAlert(title: "VPN stopped",
					 text: "You need to start the VPN proxy before you can start a recording.",
					 buttonText: "Start") { _ in
				GlassVPN.setEnabled(true)
			}.presentIn(self)
			return
		}
		currentRecording = RecordingsDB.startNew()
		QLog.Debug("start recording #\(currentRecording!.id)")
		startTimer(animate: true)
		notifyVPN(setRecording: true)
	}
	
	@IBAction private func stopRecording(_ sender: UIButton) {
		notifyVPN(setRecording: false)
		stopTimer(animate: true)
		RecordingsDB.stop(&currentRecording!)
		QLog.Debug("stop recording #\(currentRecording!.id)")
		let editVC = (children.first as! TVCPreviousRecords)
		editVC.insertAndEditRecording(currentRecording!)
		currentRecording = nil // otherwise it will restart
	}
	
	private func notifyVPN(setRecording state: Bool) {
		PrefsShared.CurrentlyRecording = state
		GlassVPN.send(.isRecording(state))
	}
	
	private func startTimer(animate: Bool) {
		guard let r = currentRecording, r.stop == nil else {
			return
		}
		recordingTimer = Timer.repeating(0.086, call: #selector(timerCallback(_:)), on: self, userInfo: Date(r.start))
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
		let block = {
			self.headerView.isHidden = setRecording
			self.buttonView.isHidden = setRecording
			self.runningView.isHidden = !setRecording
		}
		animated ? UIView.animate(withDuration: 0.3, animations: block) : block()
	}
	
	
	// MARK: Tutorial View Controller
	
	@IBAction private func showInfo(_ sender: UIButton) {
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("How to record?\n")
			.normal("\nBefore you begin a new recording make sure that you quit all running applications. " +
				"Tap on the 'Start Recording' button and switch to the application you'd like to inspect. " +
				"Use the App as you would normally. Try to get to all corners and functionality the App provides. " +
				"When you feel that you have captured enough content, come back to ").italic("AppCheck").normal(" and stop the recording." +
				"\n\n" +
				"Upon completion you will find your recording in the section below. " +
				"You can review your results and remove user specific information if necessary.")
		))
		x.buttonTitleDone = "Close"
		x.present()
	}
	
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
			Prefs.DidShowTutorial.Recordings = true
		}
	}
}
