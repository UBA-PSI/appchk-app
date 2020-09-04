import UIKit

protocol VCEditTextDelegate {
	func editText(didFinish text: String)
}

class VCEditText: UIViewController, UITextViewDelegate {
	
	var text: String!
	var delegate: VCEditTextDelegate!
	
	@IBOutlet private var textView: UITextView!
	@IBOutlet private var textBottom: NSLayoutConstraint!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.text = text
		textView.becomeFirstResponder()
		
		UIResponder.keyboardWillShowNotification.observe(call: #selector(keyboardWillShow), on: self)
		UIResponder.keyboardWillHideNotification.observe(call: #selector(keyboardWillHide), on: self)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		delegate.editText(didFinish: textView.text)
	}
	
	
	// MARK: - Adapt to Keyboard
	
	@objc func keyboardWillShow(_ notification: NSNotification) {
		textBottom.constant = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0
	}
	
	@objc func keyboardWillHide(_ notification: NSNotification) {
		textBottom.constant = 0
	}
}
