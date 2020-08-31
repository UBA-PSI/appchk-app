import UIKit

class VCRecordings: UIViewController, UINavigationControllerDelegate {
	private var currentRecording: Recording?
	private var recordingTimer: Timer?
	private var state: CurrentRecordingState = .Off
	
	@IBOutlet private var headerView: UIView!
	@IBOutlet private var buttonView: UIView!
	@IBOutlet private var runningView: UIView!
	@IBOutlet private var timeLabel: UILabel!
	@IBOutlet private var stopButton: UIButton!
	
	override func viewDidLoad() {
		timeLabel.font = timeLabel.font.monoSpace()
		if let ongoing = RecordingsDB.getCurrent() {
			currentRecording = ongoing
			// Currently this class is the only one that changes the state,
			// if that ever changes, make sure to update local state as well
			state = PrefsShared.CurrentlyRecording
			startTimer(animate: false, longterm: state == .Background)
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
		let longterm = sender.selectedSegmentIndex == 1
		startTimer(animate: true, longterm: longterm)
		notifyVPN(setRecording: longterm ? .Background : .App)
	}
	
	@IBAction private func stopRecording(_ sender: UIButton) {
		let validRecording = (state == .Background) == currentRecording!.isLongTerm
		notifyVPN(setRecording: .Off) // will change state = .Off
		stopTimer()
		QLog.Debug("stop recording #\(currentRecording!.id)")
		RecordingsDB.stop(&currentRecording!)
		if validRecording {
			let editVC = (children.first as! TVCPreviousRecords)
			editVC.insertAndEditRecording(currentRecording!)
		} else {
			QLog.Debug("Discard illegal recording #\(currentRecording!.id)")
			RecordingsDB.delete(currentRecording!)
		}
		currentRecording = nil // otherwise it will restart
	}
	
	private func notifyVPN(setRecording state: CurrentRecordingState) {
		PrefsShared.CurrentlyRecording = state
		self.state = state
		GlassVPN.send(.isRecording(state))
	}
	
	private func updateUI(setRecording: Bool, animated: Bool) {
		stopButton.tag = 99 // tag used in timerCallback()
		stopButton.setTitle("", for: .normal) // prevent flashing while animating in and out
		let block = {
			self.headerView.isHidden = setRecording
			self.buttonView.isHidden = setRecording
			self.runningView.isHidden = !setRecording
		}
		animated ? UIView.animate(withDuration: 0.3, animations: block) : block()
	}
	
	private func startTimer(animate: Bool, longterm: Bool) {
		guard let r = currentRecording, r.stop == nil else {
			return
		}
		updateUI(setRecording: true, animated: animate)
		let freq = longterm ? 1 : 0.086
		let obj = (longterm, Date(r.start))
		recordingTimer = Timer.repeating(freq, call: #selector(timerCallback(_:)), on: self, userInfo: obj)
		recordingTimer!.fire() // update label immediately
	}
	
	private func stopTimer() {
		recordingTimer?.invalidate()
		recordingTimer = nil
		updateUI(setRecording: false, animated: true)
	}
	
	@objc private func timerCallback(_ sender: Timer) {
		let (slow, start) = sender.userInfo as! (Bool, Date)
		timeLabel.text = TimeFormat.since(start, millis: !slow, hours: slow)
		let valid = slow == currentRecording!.isLongTerm
		let validInt = (valid ? 1 : 0)
		if stopButton.tag != validInt {
			stopButton.tag = validInt
			stopButton.setTitle(valid ? "Stop" : slow ? "Cancel" : "Discard", for: .normal)
		}
	}
	
	
	// MARK: Tutorial View Controller
	
	@IBAction private func showInfo(_ sender: UIButton) {
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("How to record?\n")
			.normal("\nThere are two types: specific app recordings and general background activity. " +
					"The former are usually 3 – 5 minutes long, the latter need to be at least an hour long.")
			.h2("\n\nApp recording\n")
			.normal("Before you begin make sure that you quit all running applications and wait a few seconds. " +
					"Tap on the 'App' recording button and switch to the application you'd like to inspect. " +
					"Use the App as you would normally. Try to get to all corners and functionality the App provides. " +
					"When you feel that you have captured enough content, come back to ").italic("AppCheck").normal(" and stop the recording.")
			.h2("\n\nBackground recording\n")
			.normal("Will answer one simple question: What communications happen while you aren't using your device. " +
					"You should solely start a background recording when you know you aren't going to use your device in the near future. " +
					"For example, before you go to bed.\n" +
					"As soon as you start using your device, you should stop the recording to avoid distorting the results.")
			.h2("\n\nFinish\n")
			.normal("Upon completion you will find your recording in the section below. " +
					"You can review your results and remove any user specific information if necessary.\n")
		))
		x.buttonTitleDone = "Close"
		x.present()
	}
	
	@objc private func showTutorial() {
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(QuickUI.text(attributed: NSMutableAttributedString()
			.h1("What are Recordings?\n")
			.normal("\nSimilar to the default logging, recordings will intercept every request and log it for later review. " +
				"App recordings are usually 3 – 5 minutes long and cover a single application. " +
				"You can utilize recordings for App analysis or to get a ground truth on background traffic." +
				"\n\n" +
				"Optionally, you can help us by providing your app specific recordings. " +
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
