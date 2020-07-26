import UIKit

class VCEditRecording: UIViewController, UITextFieldDelegate, UITextViewDelegate {
	var record: Recording!
	var deleteOnCancel: Bool = false
	
	@IBOutlet private var buttonCancel: UIBarButtonItem!
	@IBOutlet private var buttonSave: UIBarButtonItem!
	@IBOutlet private var inputTitle: UITextField!
	@IBOutlet private var inputNotes: UITextView!
	@IBOutlet private var inputDetails: UITextView!
	@IBOutlet private var noteBottom: NSLayoutConstraint!
	
	override func viewDidLoad() {
		inputTitle.placeholder = record.fallbackTitle
		inputTitle.text = record.title
		inputNotes.text = record.notes
		inputDetails.text = """
			Start:		\(DateFormat.seconds(record.start))
			End:		\(record.stop == nil ? "?" : DateFormat.seconds(record.stop!))
			Duration:	\(TimeFormat.from(record.duration ?? 0))
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
	
	
	// MARK: Save & Cancel Buttons
	
	@IBAction func didTapSave(_ sender: UIBarButtonItem) {
		let newlyCreated = deleteOnCancel
		if newlyCreated {
			// if remains true, `viewDidDisappear` will delete the record
			deleteOnCancel = false
		}
		QLog.Debug("updating record #\(record.id)")
		record.title = (inputTitle.text == "") ? nil : inputTitle.text
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
	
	@IBAction func didTapCancel(_ sender: UIBarButtonItem) {
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
		let changed = (inputTitle.text != record.title ?? "" || inputNotes.text != record.notes ?? "")
		buttonSave.isEnabled = changed || deleteOnCancel // always allow save for new recordings
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField == inputTitle ? inputNotes.becomeFirstResponder() : true
	}
}
