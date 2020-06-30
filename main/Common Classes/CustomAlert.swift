import UIKit

class CustomAlert<CustomView: UIView>: UIViewController {
	
	private let alertTitle: String?
	private let alertDetail: String?
	
	private let customView: CustomView
	private var callback: ((CustomView) -> Void)?
	
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
	}
	
	override var isModalInPresentation: Bool { set{} get{true} }
	override var modalPresentationStyle: UIModalPresentationStyle { set{} get{.custom} }
	override var transitioningDelegate: UIViewControllerTransitioningDelegate? {
		set {} get {
			SlideInTransitioningDelegate(for: .bottom, modal: true)
		}
	}
	
	internal override func loadView() {
		let control = UIView()
		control.backgroundColor = .sysBackground
		view = control
		
		var tmpPrevivous: UIView? = nil
		
		func adaptive(margin: CGFloat, _ fn: () -> NSLayoutConstraint) {
			regularConstraints.append(fn() + margin)
			compactConstraints.append(fn() + margin/2)
		}
		
		func addLabel(_ lbl: UILabel) {
			lbl.numberOfLines = 0
			control.addSubview(lbl)
			lbl.anchor([.leading, .trailing], to: control.layoutMarginsGuide)
			if let p = tmpPrevivous {
				adaptive(margin: 16) { lbl.topAnchor =&= p.bottomAnchor }
			} else {
				adaptive(margin: 12) { lbl.topAnchor =&= control.layoutMarginsGuide.topAnchor }
			}
			tmpPrevivous = lbl
		}
		
		// Alert title & description
		if let t = alertTitle {
			let lbl = QuickUI.label(t, align: .center, style: .subheadline)
			lbl.font = lbl.font.bold()
			addLabel(lbl)
		}
		
		if let d = alertDetail {
			addLabel(QuickUI.label(d, align: .center, style: .footnote))
		}
		
		// User content
		control.addSubview(customView)
		customView.anchor([.leading, .trailing], to: control)
		if let p = tmpPrevivous {
			customView.topAnchor =&= p.bottomAnchor | .defaultHigh
		} else {
			customView.topAnchor =&= control.layoutMarginsGuide.topAnchor
		}
		
		// Action buttons
		control.addSubview(buttonsBar)
		buttonsBar.anchor([.leading, .trailing], to: control.layoutMarginsGuide, margin: 8)
		buttonsBar.topAnchor =&= customView.bottomAnchor | .defaultHigh
		
		adaptive(margin: 12) { control.layoutMarginsGuide.bottomAnchor =&= buttonsBar.bottomAnchor }
		
		adaptToNewTraits(traitCollection)
		view.frame.size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
	}
	
	
	// MARK: - Adaptive Traits
	
	private var compactConstraints: [NSLayoutConstraint] = []
	private var regularConstraints: [NSLayoutConstraint] = []
	
	private func adaptToNewTraits(_ traits: UITraitCollection) {
		let flag = traits.verticalSizeClass == .compact
		NSLayoutConstraint.deactivate(flag ? regularConstraints : compactConstraints)
		NSLayoutConstraint.activate(flag ? compactConstraints : regularConstraints)
		view.setNeedsLayout()
	}
	
	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		super.willTransition(to: newCollection, with: coordinator)
		adaptToNewTraits(newCollection)
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
			self.callback?(self.customView)
			self.callback = nil
		}
	}
	
	
	// MARK: - Present & Dismiss
	
	func present(in viewController: UIViewController, onSuccess: @escaping (CustomView) -> Void) {
		callback = onSuccess
		viewController.present(self, animated: true)
	}
}

// ###################################
// #
// #    MARK: - Date Picker Alert
// #
// ###################################

class DatePickerAlert : CustomAlert<UIDatePicker> {
	
	let datePicker = UIDatePicker()
	
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
	
	let pickerView = UIPickerView()
	private let dataSource: [[String]]
	private let compWidths: [CGFloat]
	
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
