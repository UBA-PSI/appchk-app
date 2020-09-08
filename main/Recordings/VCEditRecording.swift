import UIKit

class VCEditRecording: UIViewController, UITextFieldDelegate, UITextViewDelegate, TVCAppSearchDelegate {
	
	var record: Recording!
	var deleteOnCancel: Bool = false
	var appId: String?
	
	@IBOutlet private var buttonCancel: UIBarButtonItem!
	@IBOutlet private var buttonSave: UIBarButtonItem!
	@IBOutlet private var appTitle: UILabel!
	@IBOutlet private var appDeveloper: UILabel!
	@IBOutlet private var appIcon: UIImageView!
	@IBOutlet private var inputNotes: UITextView!
	@IBOutlet private var inputDetails: UITextView!
	@IBOutlet private var noteBottom: NSLayoutConstraint!
	
	@IBOutlet private var chooseAppTap: UITapGestureRecognizer!
	
	override func viewDidLoad() {
		if record.isLongTerm {
			appId = nil
			appIcon.image = nil
			appTitle.text = record.fallbackTitle
			appDeveloper.text = nil
			chooseAppTap.isEnabled = false
		} else {
			appId = record.appId
			appIcon.image = BundleIcon.image(record.appId)
			appIcon.layer.cornerRadius = 6.75
			appIcon.layer.masksToBounds = true
			if record.appId == nil {
				appTitle.text = "Tap here to choose app"
				appDeveloper.text = record.title
			} else {
				appTitle.text = record.title ?? record.fallbackTitle
				appDeveloper.text = record.subtitle
			}
		}
		inputNotes.text = record.notes
		inputDetails.text = """
			Start:		\(DateFormat.seconds(record.start))
			End:		\(record.stop == nil ? "?" : DateFormat.seconds(record.stop!))
			Duration:	\(TimeFormat.from(record.duration))
			"""
		validateSaveButton()
		if deleteOnCancel { // mark as destructive
			buttonCancel.tintColor = .systemRed
			if #available(iOS 13.0, *) {
				isModalInPresentation = true
			}
		}
		UIResponder.keyboardWillShowNotification.observe(call: #selector(keyboardWillShow), on: self)
		UIResponder.keyboardWillHideNotification.observe(call: #selector(keyboardWillHide), on: self)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let tvc = segue.destination as? TVCAppSearch {
			tvc.delegate = self
		}
	}
	
	// MARK: Save & Cancel Buttons
	
	@IBAction func didTapSave() {
		let newlyCreated = deleteOnCancel
		if newlyCreated {
			// if remains true, `viewDidDisappear` will delete the record
			deleteOnCancel = false
		}
		QLog.Debug("updating record #\(record.id)")
		if let id = appId, id != "" {
			record.appId = id
			record.title = (appTitle.text == "") ? nil : appTitle.text
			record.subtitle = (appDeveloper.text == "") ? nil : appDeveloper.text
		} else {
			record.appId = nil
			record.title = nil
			record.subtitle = nil
		}
		record.notes = (inputNotes.text == "") ? nil : inputNotes.text
		dismiss(animated: true) {
			RecordingsDB.update(self.record)
			if newlyCreated {
				RecordingsDB.persist(self.record)
				if Prefs.RecordingReminder.Enabled {
					PushNotification.scheduleRecordingReminder(force: true)
				}
			}
		}
	}
	
	@IBAction func didTapCancel() {
		QLog.Debug("discard edit of record #\(record.id)")
		dismiss(animated: true)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		if deleteOnCancel {
			QLog.Debug("deleting record #\(record.id)")
			RecordingsDB.delete(record)
			deleteOnCancel = false
		}
	}
	
	@IBAction func didTapFilter() {
		if buttonSave.isEnabled {
			NotificationBanner("Filter set", style: .ok).present(in: self, hideAfter: 1)
		} else {
			(presentingViewController as? TBCMain)?.openTab(0)
			didTapCancel()
		}
		VCDateFilter.setFilter(range: record.start, to: record.stop)
	}
	
	
	// MARK: Handle Keyboard & Notes Frame
	
	private var isEditingNotes: Bool = false
	private var keyboardHeight: CGFloat = 0
	
	@IBAction func hideKeyboard() { view.endEditing(false) }
	
	func textViewDidBeginEditing(_ textView: UITextView) {
		if textView == inputNotes {
			isEditingNotes = true
			updateKeyboard()
		}
	}
	
	func textViewDidEndEditing(_ textView: UITextView) {
		if textView == inputNotes {
			isEditingNotes = false
			updateKeyboard()
		}
	}
	
	@objc func keyboardWillShow(_ notification: NSNotification) {
		keyboardHeight = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0
		updateKeyboard()
	}
	
	@objc func keyboardWillHide(_ notification: NSNotification) {
		keyboardHeight = 0
		updateKeyboard()
	}
	
	private func updateKeyboard() {
		guard let parent = inputNotes.superview, let stack = parent.superview else {
			return
		}
		let adjust = (isEditingNotes && keyboardHeight > 0)
		stack.subviews.forEach{ $0.isHidden = (adjust && $0 != parent) }
		
		let title = parent.subviews.first as! UILabel
		title.font = .preferredFont(forTextStyle: adjust ? .subheadline : .title2)
		title.sizeToFit()
		title.frame.size.width = parent.frame.width
		
		noteBottom.constant = adjust ? view.frame.height - stack.frame.maxY - keyboardHeight : 0
	}
	
	
	// MARK: TextField & TextView Delegate
	
	func textFieldDidChangeSelection(_ _: UITextField) { validateSaveButton() }
	func textViewDidChange(_ _: UITextView) { validateSaveButton() }
	
	private func validateSaveButton() {
		let changed = (appId != record.appId
			|| (appTitle.text != record.title && appTitle.text != "Tap here to choose app" && appTitle.text != record.fallbackTitle)
			|| appDeveloper.text != record.subtitle
			|| inputNotes.text != record.notes ?? "")
		buttonSave.isEnabled = changed || deleteOnCancel // always allow save for new recordings
	}
	
	func appSearch(didSelect bundleId: String, appName: String?, developer: String?) {
		appId = bundleId
		appTitle.text = appName
		appDeveloper.text = developer
		appIcon.image = BundleIcon.image(bundleId)
		validateSaveButton()
	}
}
