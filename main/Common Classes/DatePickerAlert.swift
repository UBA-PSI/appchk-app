import UIKit

class DatePickerAlert: UIViewController {
	
	private var callback: (Date) -> Void
	private let picker: UIDatePicker = {
		let x = UIDatePicker()
		let h = x.sizeThatFits(.zero).height
		x.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: h)
		return x
	}()
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	@discardableResult required init(presentIn viewController: UIViewController, configure: ((UIDatePicker) -> Void)? = nil, onSuccess: @escaping (Date) -> Void) {
		callback = onSuccess
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .custom
		if #available(iOS 13.0, *) {
			isModalInPresentation = true
		}
		presentIn(viewController, configure)
	}
	
	internal override func loadView() {
		let cancel = QuickUI.button("Cancel", target: self, action: #selector(didTapCancel))
		let save = QuickUI.button("Save", target: self, action: #selector(didTapSave))
		save.titleLabel?.font = save.titleLabel?.font.bold()
		//cancel.setTitleColor(.systemRed, for: .normal)
		
		let buttons = UIStackView(arrangedSubviews: [cancel, save])
		buttons.axis = .horizontal
		buttons.distribution = .fillEqually
		
		let bg = UIView(frame: picker.frame)
		bg.frame.size.height += buttons.frame.height + 15
		bg.frame.origin.y = UIScreen.main.bounds.height - bg.frame.height - 15
		bg.backgroundColor = .sysBg
		bg.addSubview(picker)
		bg.addSubview(buttons)
		
		let clearBg = UIView()
		clearBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		clearBg.addSubview(bg)
		
		picker.anchor([.leading, .trailing, .top], to: bg)
		picker.bottomAnchor =&= buttons.topAnchor
		buttons.anchor([.leading, .trailing], to: bg)
		buttons.bottomAnchor =&= bg.bottomAnchor - 15
		bg.anchor([.leading, .trailing, .bottom], to: clearBg)
		
		view = clearBg
		view.isHidden = true // otherwise picker will flash on present
	}
	
	@objc private func didTapSave() {
		dismiss(animated: true) {
			self.callback(self.picker.date)
		}
	}
	
	@objc private func didTapCancel() {
		dismiss(animated: true)
	}
	
	private func presentIn(_ viewController: UIViewController, _ configure: ((UIDatePicker) -> Void)? = nil) {
		viewController.present(self, animated: false) {
			let control = self.view.subviews.first!
			let prev = control.frame.origin.y
			control.frame.origin.y += control.frame.height
			self.view.isHidden = false
			
			configure?(self.picker)
			
			UIView.animate(withDuration: 0.3) {
				self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
				control.frame.origin.y = prev
			}
		}
	}
	
	override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
		UIView.animate(withDuration: 0.3, animations: {
			let control = self.view.subviews.first!
			self.view.backgroundColor = .clear
			control.frame.origin.y += control.frame.height
		}) { _ in
			super.dismiss(animated: false, completion: completion)
		}
	}
}
