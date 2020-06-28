import UIKit

class CustomAlert<CustomView: UIView>: UIViewController {
	
	private let alertTitle: String?
	private let alertDetail: String?
	
	private let customView: CustomView
	private var callback: ((CustomView) -> Void)!
	
	private let backgroundShadow: UIView = {
		let shadow = UIView()
		shadow.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		return shadow
	}()
	
	private let control: UIView = {
		let x = UIView()
		x.backgroundColor = .sysBackground
		return x
	}()
	
	/// Default: `[Cancel, Save]`
	let buttonsBar: UIStackView = {
		let cancel = QuickUI.button("Cancel", target: self, action: #selector(didTapCancel))
		let save = QuickUI.button("Save", target: self, action: #selector(didTapSave))
		save.titleLabel?.font = save.titleLabel?.font.bold()
		let bar = UIStackView(arrangedSubviews: [cancel, save])
		bar.axis = .horizontal
		bar.distribution = .equalSpacing
		return bar
	}()
	
	
	// MARK: - Init
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	init(title: String? = nil, detail: String? = nil, view custom: CustomView) {
		alertTitle = title
		alertDetail = detail
		customView = custom
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .custom
		if #available(iOS 13.0, *) {
			isModalInPresentation = true
		}
	}
	
	internal override func loadView() {
		view = UIView()
		view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.isHidden = true // otherwise control will flash on present
		
		var h: CGFloat = 0
		var prevView: UIView? = nil
		func appendView(_ x: UIView, top: CGFloat, lr: CGFloat) {
			control.addSubview(x)
			// sticky edges horizontally
			x.anchor([.leading, .trailing], to: control, margin: lr)
			chainPrevious(to: x.topAnchor, padding: top)
			prevView = x
			h += x.frame.height + top
		}
		func chainPrevious(to anchor: NSLayoutYAxisAnchor, padding p: CGFloat) {
			anchor =&= (prevView?.bottomAnchor ?? control.topAnchor) + p/2 | .defaultLow
			anchor =&= (prevView?.bottomAnchor ?? control.topAnchor) + p | .defaultHigh
		}
		
		if let t = alertTitle {
			let lbl = QuickUI.label(t, align: .center, style: .headline)
			lbl.numberOfLines = 0
			appendView(lbl, top: 16, lr: 16)
		}
		if let d = alertDetail {
			let lbl = QuickUI.label(d, align: .center, style: .subheadline)
			lbl.numberOfLines = 0
			appendView(lbl, top: 16, lr: 16)
		}
		appendView(customView, top: (prevView == nil) ? 0 : 16, lr: 0)
		appendView(buttonsBar, top: 0, lr: 25)
		chainPrevious(to: control.bottomAnchor, padding: 15)
		h += 15 // buttonsBar has 15px padding
		
		let screen = UIScreen.main.bounds.size
		control.frame = CGRect(x: 0, y: screen.height - h, width: screen.width, height: h)
		
		view.addSubview(control)
		control.anchor([.leading, .trailing, .bottom], to: view!)
		control.heightAnchor =<= view.heightAnchor
	}
	
	
	// MARK: - User Interaction
	
	override var keyCommands: [UIKeyCommand]? {
		[UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(didTapCancel))]
	}
	
	@objc private func didTapCancel() {
		callback = nil
		dismiss(animated: true)
	}
	
	@objc private func didTapSave() {
		dismiss(animated: true) {
			self.callback(self.customView)
			self.callback = nil
		}
	}
	
	
	// MARK: - Present & Dismiss
	
	func present(in viewController: UIViewController, onSuccess: @escaping (CustomView) -> Void) {
		callback = onSuccess
		loadViewIfNeeded()
		viewController.present(self, animated: false) {
			let prev = self.control.frame.origin.y
			self.control.frame.origin.y += self.control.frame.height
			self.view.isHidden = false
			
			UIView.animate(withDuration: 0.3) {
				self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
				self.control.frame.origin.y = prev
			}
		}
	}
	
	override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
		UIView.animate(withDuration: 0.3, animations: {
			self.view.backgroundColor = .clear
			self.control.frame.origin.y += self.control.frame.height
		}) { _ in
			super.dismiss(animated: false, completion: completion)
		}
	}
}

// ###################################
// #
// #    MARK: - Date Picker Alert
// #
// ###################################

class DatePickerAlert : CustomAlert<UIDatePicker> {
	
	let datePicker: UIDatePicker = {
		let x = UIDatePicker()
		x.frame.size.height = x.sizeThatFits(.zero).height
		return x
	}()
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	init(title: String? = nil, detail: String? = nil, initial date: Date? = nil) {
		if let date = date {
			datePicker.setDate(date, animated: false)
		}
		super.init(title: title, detail: detail, view: datePicker)
		
		let now = QuickUI.button("Now", target: self, action: #selector(didTapNow))
		now.titleLabel?.font = now.titleLabel?.font.bold()
		now.setTitleColor(.sysLabel, for: .normal)
		buttonsBar.insertArrangedSubview(now, at: 1)
	}
	
	@objc private func didTapNow() {
		datePicker.date = Date()
	}
	
	func present(in viewController: UIViewController, onSuccess: @escaping (UIDatePicker, Date) -> Void) {
		super.present(in: viewController) {
			onSuccess($0, $0.date)
		}
	}
}

// #######################################
// #
// #    MARK: - Duration Picker Alert
// #
// #######################################

class DurationPickerAlert: CustomAlert<UIPickerView>, UIPickerViewDataSource, UIPickerViewDelegate {
	
	private let dataSource: [[String]]
	private let compWidths: [CGFloat]
	let pickerView: UIPickerView = {
		let x = UIPickerView()
		x.frame.size.height = x.sizeThatFits(.zero).height
		return x
	}()
	
	
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	/// - Parameter options: [[List of labels] per component]
	/// - Parameter widths: If `nil` set all components to equal width
	init(title: String? = nil, detail: String? = nil, options: [[String]], widths: [CGFloat]? = nil) {
		assert(widths == nil || widths!.count == options.count, "widths.count != options.count")
		
		dataSource = options
		compWidths = widths ?? options.map { _ in 1 / CGFloat(options.count) }
		
		super.init(title: title, detail: detail, view: pickerView)
		
		pickerView.dataSource = self
		pickerView.delegate = self
	}
	
	func numberOfComponents(in _: UIPickerView) -> Int {
		dataSource.count
	}
	func pickerView(_: UIPickerView, numberOfRowsInComponent c: Int) -> Int {
		dataSource[c].count
	}
	func pickerView(_: UIPickerView, titleForRow r: Int, forComponent c: Int) -> String? {
		dataSource[c][r]
	}
	func pickerView(_ pickerView: UIPickerView, widthForComponent c: Int) -> CGFloat {
		compWidths[c] * pickerView.frame.width
	}
	
	func present(in viewController: UIViewController, onSuccess: @escaping (UIPickerView, [Int]) -> Void) {
		super.present(in: viewController) {
			onSuccess($0, $0.selection)
		}
	}
}

extension UIPickerView {
	var selection: [Int] {
		get { (0..<numberOfComponents).map { selectedRow(inComponent: $0) } }
		set { setSelection(newValue) }
	}
	/// - Warning: Does not check for boundaries!
	func setSelection(_ selection: [Int], animated: Bool = false) {
		assert(selection.count == numberOfComponents, "selection.count != components.count")
		for (c, i) in selection.enumerated() {
			selectRow(i, inComponent: c, animated: animated)
		}
	}
}
