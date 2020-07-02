import UIKit

enum PresentationEdge { case left, top, right, bottom }

// ########################################
// #
// #    MARK: - Transitioning Delegate
// #
// ########################################

class SlideInTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
	private var edge: PresentationEdge
	private var modal: Bool
	private var dismissable: Bool
	private var shadow: UIColor?
	
	init(for edge: PresentationEdge, modal: Bool, tapAnywhereToDismiss: Bool = false, modalBackgroundColor color: UIColor? = nil) {
		self.edge = edge
		self.dismissable = tapAnywhereToDismiss
		self.shadow = color
		self.modal = modal
	}
	
	func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
		StickyPresentationController(presented: presented, presenting: presenting, stickTo: edge, modal: modal, tapAnywhereToDismiss: dismissable, modalBackgroundColor: shadow)
	}
	
	func animationController(forPresented _: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		SlideInAnimationController(from: edge, isPresentation: true)
	}

	func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		SlideInAnimationController(from: edge, isPresentation: false)
	}
}

// ########################################
// #
// #    MARK: - Animated Transitioning
// #
// ########################################

private final class SlideInAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
	let edge: PresentationEdge
	let appear: Bool
	
	init(from edge: PresentationEdge, isPresentation: Bool) {
		self.edge = edge
		self.appear = isPresentation
		super.init()
	}
	
	func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
		(context?.isAnimated ?? true) ? 0.3 : 0.0
	}
	
	func animateTransition(using context: UIViewControllerContextTransitioning) {
		guard let vc = context.viewController(forKey: appear ? .to : .from) else { return }
		
		var to = context.finalFrame(for: vc)
		var from = to
		switch edge {
		case .left:   from.origin.x = -to.width
		case .right:  from.origin.x = context.containerView.frame.width
		case .top:    from.origin.y = -to.height
		case .bottom: from.origin.y = context.containerView.frame.height
		}
		
		if appear { context.containerView.addSubview(vc.view) }
		else { swap(&from, &to) }
		
		vc.view.frame = from
		UIView.animate(withDuration: transitionDuration(using: context), animations: {
			vc.view.frame = to
		}, completion: { finished in
			if !self.appear { vc.view.removeFromSuperview() }
			context.completeTransition(finished)
		})
	}
}

// #########################################
// #
// #    MARK: - Presentation Controller
// #
// #########################################

private class StickyPresentationController: UIPresentationController {
	private let stickTo: PresentationEdge
	private let isModal: Bool
	
	private let bg = UIView()
	private var availableSize: CGSize = .zero // save original size when resizing the container
	
	override var shouldPresentInFullscreen: Bool { false }
	override var frameOfPresentedViewInContainerView: CGRect { fittedContentFrame() }
	
	required init(presented: UIViewController, presenting: UIViewController?, stickTo edge: PresentationEdge, modal: Bool = true, tapAnywhereToDismiss: Bool = false, modalBackgroundColor bgColor: UIColor? = nil) {
		self.stickTo = edge
		self.isModal = modal
		super.init(presentedViewController: presented, presenting: presenting)
		bg.backgroundColor = bgColor ?? .init(white: 0, alpha: 0.5)
		if modal, tapAnywhereToDismiss {
			bg.addGestureRecognizer(
				UITapGestureRecognizer(target: self, action: #selector(didTapBackground))
			)
		}
	}
	
	// MARK: Present
	
	override func presentationTransitionWillBegin() {
		availableSize = containerView!.frame.size
		
		guard isModal else { return }
		containerView!.insertSubview(bg, at: 0)
		bg.alpha = 0.0
		if presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
			self.bg.alpha = 1.0
		}) != true { bg.alpha = 1.0 }
	}
	
	@objc func didTapBackground(_ sender: UITapGestureRecognizer) {
		presentingViewController.dismiss(animated: true)
	}
	
	// MARK: Dismiss
	
	override func dismissalTransitionWillBegin() {
		if presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
			self.bg.alpha = 0.0
		}) != true { bg.alpha = 0.0 }
	}
	
	override func dismissalTransitionDidEnd(_ completed: Bool) {
		if completed { bg.removeFromSuperview() }
	}
	
	// MARK: Update
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		availableSize = size
		super.viewWillTransition(to: size, with: coordinator)
	}
	
	override func containerViewDidLayoutSubviews() {
		super.containerViewDidLayoutSubviews()
		bg.frame = containerView!.bounds
		if isModal {
			presentedView!.frame = fittedContentFrame()
		} else {
			containerView!.frame = fittedContentFrame()
			presentedView!.frame = containerView!.bounds
		}
	}
	
	/// Calculate `fittedContentSize()` then offset frame to sticky edge respecting *available* container size .
	func fittedContentFrame() -> CGRect {
		var frame = CGRect(origin: .zero, size: fittedContentSize())
		switch stickTo {
		case .right:  frame.origin.x = availableSize.width - frame.width
		case .bottom: frame.origin.y = availableSize.height - frame.height
		default: break
		}
		return frame
	}
	
	/// Calculate best fitting size for available container size and presentation sticky edge.
	func fittedContentSize() -> CGSize {
		guard let target = presentedView else { return availableSize }
		let full = availableSize
		let preferred = presentedViewController.preferredContentSize
		switch stickTo {
		case .left, .right:
			let fitted = target.fittingSize(fixedHeight: full.height, preferredWidth: preferred.width)
			return CGSize(width: min(fitted.width, full.width), height: full.height)
		case .top, .bottom:
			let fitted = target.fittingSize(fixedWidth: full.width, preferredHeight: preferred.height)
			return CGSize(width: full.width, height: min(fitted.height, full.height))
		}
	}
}
