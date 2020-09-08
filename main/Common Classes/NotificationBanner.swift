import UIKit

struct NotificationBanner {
	enum Style {
		case fail, ok
	}
	
	let view: UIView
	
	init(_ msg: String, style: Style) {
		let bg, fg: UIColor
		let imgName: String
		switch style {
		case .fail:
			bg = .systemRed
			fg = UIColor.black.withAlphaComponent(0.80)
			imgName = "circle-x"
		case .ok:
			bg = .systemGreen
			fg = UIColor.black.withAlphaComponent(0.65)
			imgName = "circle-check"
		}
		view = UIView()
		view.backgroundColor = bg
		let lbl = QuickUI.label(msg, style: .callout)
		lbl.textColor = fg
		lbl.numberOfLines = 0
		lbl.font = lbl.font.bold()
		let img = QuickUI.image(UIImage(named: imgName))
		img.tintColor = fg
		view.addSubview(lbl)
		view.addSubview(img)
		img.anchor([.centerY], to: lbl)
		lbl.anchor([.bottom, .trailing], to: view.layoutMarginsGuide)
		img.widthAnchor =&= 25
		img.heightAnchor =&= 25
		if #available(iOS 11, *) {
			img.leadingAnchor =&= view.layoutMarginsGuide.leadingAnchor
			lbl.topAnchor =&= view.layoutMarginsGuide.topAnchor
		} else {
			img.leadingAnchor =&= view.leadingAnchor + 8
			lbl.topAnchor =&= view.topAnchor + 8
		}
		lbl.leadingAnchor =&= img.trailingAnchor + 8
		img.bottomAnchor =<= view.bottomAnchor - 8 | .init(rawValue: 999)
		lbl.bottomAnchor =<= view.bottomAnchor - 8 | .init(rawValue: 999)
	}
	
	/// Animate header banner from the top of the view. Show for `delay` seconds and then hide again.
	/// - Parameter onClose: Run after the close animation finishes.
	func present(in vc: UIViewController, hideAfter delay: TimeInterval = 3, onClose: (() -> Void)? = nil) {
		vc.view.addSubview(view)
		view.anchor([.leading, .trailing], to: vc.view!)
		view.widthAnchor =&= vc.view!.widthAnchor // Bug? left-right is not sufficient
		vc.view.layoutIfNeeded() // sets the height
		let h = view.frame.height
		let constraint = view.topAnchor =&= vc.view.topAnchor - h
		vc.view.layoutIfNeeded() // hide view
		UIView.animate(withDuration: 0.3, animations: {
			constraint.constant = 0
			vc.view.layoutIfNeeded() // animate view
			UIView.animate(withDuration: 0.3, delay: delay, options: .curveLinear, animations: {
				constraint.constant = -h
				vc.view.layoutIfNeeded() // hide again
			}, completion: { _ in
				self.view.removeFromSuperview()
				onClose?()
			})
		})
	}
}
