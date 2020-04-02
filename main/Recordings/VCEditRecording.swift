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
		if deleteOnCancel { // mark as destructive
			buttonCancel.tintColor = .systemRed
		}
		inputTitle.placeholder = record.fallbackTitle
		inputTitle.text = record.title
		inputNotes.text = record.notes
		inputDetails.text = """
			Start:\t\t\(record.start.asDateTime())
			End:\t\t\(record.stop?.asDateTime() ?? "?")
			Duration:\t\(record.durationString ?? "?")
			"""
	}
	
	func textFieldDidChangeSelection(_ _: UITextField) { validateInput() }
	func textViewDidChange(_ _: UITextView) { validateInput() }
	
	private func validateInput() {
		let changed = (inputTitle.text != record.title ?? "" || inputNotes.text != record.notes ?? "")
		buttonSave.isEnabled = changed
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
}
