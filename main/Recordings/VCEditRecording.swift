import UIKit

class VCEditRecording: UIViewController, UITextFieldDelegate, UITextViewDelegate {
	var record: Recording!
	var deleteOnCancel: Bool = false
	
	@IBOutlet private var buttonCancel: UIBarButtonItem!
	@IBOutlet private var buttonSave: UIBarButtonItem!
	@IBOutlet private var inputTitle: UITextField!
	@IBOutlet private var inputNotes: UITextView!
	@IBOutlet private var inputDetails: UITextView!
	
	override func viewDidLoad() {
		inputTitle.placeholder = record.fallbackTitle
		inputTitle.text = record.title
		inputNotes.text = record.notes
		inputDetails.text = """
			Start:\t\t\(record.start.asDateTime())
			End:\t\t\(record.stop?.asDateTime() ?? "?")
			Duration:\t\(record.durationString ?? "?")
			"""
		validateSaveButton()
		if deleteOnCancel { // mark as destructive
			buttonCancel.tintColor = .systemRed
		}
		UIResponder.keyboardWillShowNotification.observe(call: #selector(keyboardWillShow), on: self)
		UIResponder.keyboardWillHideNotification.observe(call: #selector(keyboardWillHide), on: self)
	}
	
	func textFieldDidChangeSelection(_ _: UITextField) { validateSaveButton() }
	func textViewDidChange(_ _: UITextView) { validateSaveButton() }
	
	private func validateSaveButton() {
		let changed = (inputTitle.text != record.title ?? "" || inputNotes.text != record.notes ?? "")
		buttonSave.isEnabled = changed || deleteOnCancel // always allow save for new recordings
	}
	
	@IBAction func didTapSave(_ sender: UIBarButtonItem) {
		if deleteOnCancel { // aka newly created
			// if remains true, `viewDidDisappear` will delete the record
			deleteOnCancel = false
			// TODO: copy db entries in new table for editing
		}
		QLog.Debug("updating record \(record.start)")
		record.title = (inputTitle.text == "") ? nil : inputTitle.text
		record.notes = (inputNotes.text == "") ? nil : inputNotes.text
		dismiss(animated: true) {
			DBWrp.recordingUpdate(self.record)
		}
	}
	
	@IBAction func didTapCancel(_ sender: UIBarButtonItem) {
		QLog.Debug("discard edit of record \(record.start)")
		dismiss(animated: true)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		if deleteOnCancel {
			QLog.Debug("deleting record \(record.start)")
			DBWrp.recordingDelete(record)
			deleteOnCancel = false
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField == inputTitle {
			return inputNotes.becomeFirstResponder()
		}
		return true
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
		let shouldAdjust = (isEditingNotes && keyboardHeight > 0)
		let noteTitle = parent.subviews.first!
		noteTitle.isHidden = shouldAdjust
		stack.subviews.forEach{ $0.isHidden = (shouldAdjust && $0 != parent) }
		
		if shouldAdjust {
			inputNotes.frame.origin.y = 0
			inputNotes.frame.size.height = view.frame.height - keyboardHeight - stack.frame.minY - 4
			inputNotes.autoresizingMask = .init(arrayLiteral: .flexibleWidth, .flexibleBottomMargin)
		} else {
			inputNotes.frame.origin.y = noteTitle.frame.height
			inputNotes.frame.size.height = parent.frame.height - noteTitle.frame.height
			inputNotes.autoresizingMask = .init(arrayLiteral: .flexibleWidth, .flexibleHeight)
		}
	}
}
