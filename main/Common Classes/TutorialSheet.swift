import UIKit

fileprivate let margin: CGFloat = 20
fileprivate let cornerRadius: CGFloat = 15
fileprivate let uniRect = CGRect(x: 0, y: 0, width: 500, height: 500)

class TutorialSheet: UIViewController, UIScrollViewDelegate {
	
	public var buttonTitleNext: String = "Next"
	public var buttonTitleDone: String = "Close"
	
	private var priorIndex: Int?
	private var lastAnchor: NSLayoutConstraint?
	private var shouldAnimate: Bool = true
	private var shouldCloseBlock: (() -> Bool)? = nil
	private var didCloseBlock: (() -> Void)? = nil
	
	private let sheetBg: UIView = {
		let x = UIView(frame: uniRect)
		x.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		x.backgroundColor = .sysBg
		x.layer.cornerRadius = cornerRadius
		x.layer.shadowColor = UIColor.black.cgColor
		x.layer.shadowRadius = 10
		x.layer.shadowOpacity = 0.75
		x.layer.shadowOffset = CGSize(width: 0, height: 4)
		return x
	}()
	
	private let pager: UIPageControl = {
		let x = UIPageControl(frame: uniRect)
		x.frame.size.height = x.size(forNumberOfPages: 1).height
		x.currentPageIndicatorTintColor = UIColor.sysFg.withAlphaComponent(0.5)
		x.pageIndicatorTintColor = UIColor.sysFg.withAlphaComponent(0.25)
		x.numberOfPages = 0
		x.hidesForSinglePage = true
		x.addTarget(self, action: #selector(pagerDidChange), for: .valueChanged)
		return x
	}()
	
	private let pageScroll: UIScrollView = {
		let x = UIScrollView(frame: uniRect)
		x.bounces = false
		x.isPagingEnabled = true
		x.showsVerticalScrollIndicator = false
		x.showsHorizontalScrollIndicator = false
		
		let content = UIView()
		x.addSubview(content)
		content.translatesAutoresizingMaskIntoConstraints = false
		content.anchor([.left, .right, .top, .bottom], to: x)
		content.anchor([.width, .height], to: x) | .defaultLow
		return x
	}()
	
	private let button: UIButton = {
		let x = QuickUI.button("", target: self, action: #selector(buttonTapped))
		x.contentEdgeInsets = UIEdgeInsets(all: 8)
		return x
	}()
	
	
	// MARK: Init
	
	required init?(coder: NSCoder) { super.init(coder: coder) }
	
	required init() {
		super.init(nibName: nil, bundle: nil)
		view = makeControlUI()
		modalPresentationStyle = .custom
		if #available(iOS 13.0, *) {
			isModalInPresentation = true
		}
		UIDevice.orientationDidChangeNotification.observe(call: #selector(didChangeOrientation), on: self)
	}
	
	/// Present Tutorial Sheet Controller
	/// - Parameter viewController: If set to `nil`, use main application as canvas. (Default: `nil`)
	/// - Parameter animate: Use `present` and `dismiss` animations. (Default: `true`)
	/// - Parameter shouldClose: Called before the view controller is dismissed. Return `false` to prevent the dismissal.
	///                          Use this block to extract user data from input fields. (Default: `nil`)
	/// - Parameter didClose: Called after the view controller is completely dismissed (with animations).
	///                       Use this block to update UI and visible changes. (Default: `nil`)
	func present(in viewController: UIViewController? = nil, animate: Bool = true, shouldClose: (() -> Bool)? = nil, didClose: (() -> Void)? = nil) {
		guard let vc = viewController ?? UIApplication.shared.keyWindow?.rootViewController else {
			return
		}
		shouldCloseBlock = shouldClose
		didCloseBlock = didClose
		shouldAnimate = animate
		vc.present(self, animated: animate)
	}
	
	
	// MARK: Dynamic UI
	
	@discardableResult func addSheet(_ closure: ((UIStackView) -> Void)? = nil) -> UIStackView {
		pager.numberOfPages += 1
		updateButtonTitle()
		let x = UIStackView(frame: pageScroll.bounds)
		x.translatesAutoresizingMaskIntoConstraints = false
		x.axis = .vertical
		x.backgroundColor = UIColor.black
		x.isOpaque = true
		guard let content = pageScroll.subviews.first else {
			return x
		}
		let prev = content.subviews.last
		content.addSubview(x)
		x.anchor([.top, .width, .height], to: pageScroll)
		x.leadingAnchor =&= (prev==nil ? content.leadingAnchor : prev!.trailingAnchor)
		lastAnchor?.isActive = false
		lastAnchor = (x.trailingAnchor =&= pageScroll.trailingAnchor)
		closure?(x)
		return x
	}
	
	
	// MARK: Static UI
	
	private func makeControlUI() -> UIView {
		pageScroll.delegate = self
		
		sheetBg.addSubview(pager)
		sheetBg.addSubview(pageScroll)
		sheetBg.addSubview(button)
		
		for x in sheetBg.subviews { x.translatesAutoresizingMaskIntoConstraints = false }
		
		pager.anchor([.top, .left, .right], to: sheetBg)
		pageScroll.topAnchor =&= pager.bottomAnchor
		pageScroll.anchor([.left, .right, .top, .bottom], to: sheetBg, margin: cornerRadius/2) | .defaultHigh
		button.topAnchor =&= pageScroll.bottomAnchor
		button.anchor([.bottom, .centerX], to: sheetBg)
//		button.bottomAnchor =&= sheetBg.bottomAnchor - 30
//		button.centerXAnchor =&= sheetBg.centerXAnchor
		
		let bg = UIView(frame: uniRect)
		bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		bg.addSubview(sheetBg)
		
		let h: CGFloat = UIApplication.shared.isStatusBarHidden ? 0 : UIApplication.shared.statusBarFrame.height
		sheetBg.frame = bg.frame.inset(by: UIEdgeInsets(all: margin, top: margin + h))
		return bg
	}
	
	
	// MARK: Delegates
	
	override func viewWillLayoutSubviews() {
		priorIndex = pager.currentPage
	}
	
	@objc private func didChangeOrientation() {
		if let i = priorIndex {
			priorIndex = nil
			switchToSheet(i, animated: false)
		}
		for case let x as UIStackView in pageScroll.subviews.first!.subviews {
			x.axis = (x.frame.width > x.frame.height) ? .horizontal : .vertical
		}
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let w = scrollView.frame.width
		let new = Int((scrollView.contentOffset.x + w/2) / w)
		if pager.currentPage != new {
			pager.currentPage = new
			updateButtonTitle()
		}
	}
	
	@objc private func pagerDidChange(sender: UIPageControl) {
		switchToSheet(sender.currentPage, animated: true)
	}
	
	private func switchToSheet(_ i: Int, animated: Bool) {
		pageScroll.setContentOffset(CGPoint(x: CGFloat(i) * pageScroll.bounds.width, y: 0), animated: animated)
	}
	
	private func updateButtonTitle() {
		let last = (pager.currentPage == pager.numberOfPages - 1)
		let title = last ? buttonTitleDone : buttonTitleNext
		if button.title(for: .normal) != title {
			button.setTitle(title, for: .normal)
		}
	}
	
	@objc private func buttonTapped() {
		let next = pager.currentPage + 1
		if next < pager.numberOfPages {
			switchToSheet(next, animated: true)
		} else {
			if shouldCloseBlock?() ?? true {
				dismiss(animated: shouldAnimate, completion: didCloseBlock)
			}
		}
	}
}
