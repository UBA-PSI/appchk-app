import UIKit

protocol AnalysisBarDelegate {
	func analysisBarWillOpenCoOccurrence() -> (domain: String, isFQDN: Bool)
}

class VCAnalysisBar: UIViewController, UITabBarDelegate {
	
	@IBOutlet private var tabBar: UITabBar!
	
	override func viewDidLoad() {
		if #available(iOS 10.0, *) {
			tabBar.unselectedItemTintColor = .sysLink
		}
		super.viewDidLoad()
	}
	
	override func willMove(toParent parent: UIViewController?) {
		super.willMove(toParent: parent)
		let enabled = (parent as? AnalysisBarDelegate) != nil
		for item in tabBar.items! { item.isEnabled = enabled }
	}
	
	// MARK: - Tab Bar Appearance
	
	override func viewWillAppear(_: Bool) {
		resizeTableViewHeader()
	}
	
	override func traitCollectionDidChange(_: UITraitCollection?) {
		resizeTableViewHeader()
	}
	
	func resizeTableViewHeader() {
		guard let tableView = (parent as? UITableViewController)?.tableView,
			let head = tableView.tableHeaderView else { return }
		// Recalculate and apply new height. Otherwise tabBar won't compress
		tabBar.sizeToFit()
		head.frame.size.height = tabBar.frame.height
		tableView.tableHeaderView = head
	}
	
	// MARK: - Tab Bar Delegate
	
	func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
		tabBar.selectedItem = nil
		openCoOccurrence()
	}
	
	private func openCoOccurrence() {
		guard let delegate = parent as? AnalysisBarDelegate,
			let vc: VCCoOccurrence = storyboard?.load("IBCoOccurrence") else {
			return
		}
		let info = delegate.analysisBarWillOpenCoOccurrence()
		vc.domainName = info.domain
		vc.isFQDN = info.isFQDN
		present(vc, animated: true)
	}
}
