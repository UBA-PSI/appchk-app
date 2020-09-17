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
	@IBOutlet private var startSegment: UISegmentedControl!
	
	override func viewDidLoad() {
		startSegment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor.sysLink], for: .normal)
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
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				let x = TutorialSheet()
				x.addSheet().addArrangedSubview(TinyMarkdown.load("tut-recording-1"))
				x.addSheet().addArrangedSubview(TinyMarkdown.load("tut-recording-2"))
				x.buttonTitleDone = "Got it"
				x.present(didClose: {
					Prefs.DidShowTutorial.Recordings = true
				})
			}
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
	
	@IBAction private func showInfo(_ sender: UIButton?) {
		let x = TutorialSheet()
		x.addSheet().addArrangedSubview(TinyMarkdown.load("tut-recording-howto"))
		x.buttonTitleDone = "Close"
		x.present(didClose: {
			Prefs.DidShowTutorial.RecordingHowTo = true
		})
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
		guard Prefs.DidShowTutorial.RecordingHowTo else {
			showInfo(nil) // show at least once. Later, user can click the help icon.
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
}
