import UIKit

/// Assigns a `UISearchBar` to the `tableHeaderView` property of a `UITableView`.
class SearchBarManager: NSObject, UISearchBarDelegate {
	
	private weak var tableView: UITableView?
	private let searchBar: UISearchBar
	private(set) var active: Bool = false
	
	typealias OnChange = (String) -> Void
	typealias OnHide = () -> Void
	private var onChangeCallback: OnChange!
	private var onHideCallback: OnHide?
	
	/// Prepare `UISearchBar` for user input
	/// - Parameter tableView: The `tableHeaderView` property is used for display.
	required init(on tableView: UITableView) {
		self.tableView = tableView
		searchBar = UISearchBar(frame: CGRect.init(x: 0, y: 0, width: 20, height: 10))
		searchBar.sizeToFit() // sets height, width is set by table view header
		searchBar.showsCancelButton = true
		searchBar.autocapitalizationType = .none
		searchBar.autocorrectionType = .no
		super.init()
		searchBar.delegate = self
		
		UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
			.defaultTextAttributes = [.font: UIFont.preferredFont(forTextStyle: .body)]
	}
	
	
	// MARK: Show & Hide
	
	/// Insert search bar in `tableView` and call `reloadData()` after animation.
	/// - Parameters:
	///   - onHide: Code that will be executed once the search bar is dismissed.
	///   - onChange: Code that will be executed every time the user changes the text (with 0.2s delay)
	func show(onHide: OnHide? = nil, onChange: @escaping OnChange) {
		onChangeCallback = onChange
		onHideCallback = onHide
		setSearchBarHidden(false)
	}
	
	/// Remove search bar from `tableView` and call `reloadData()` after animation.
	func hide() {
		setSearchBarHidden(true)
	}
	
	/// Internal method to insert or remove the `UISearchBar` as `tableHeaderView`
	private func setSearchBarHidden(_ flag: Bool) {
		active = !flag
		searchBar.text = nil
		guard let tv = tableView else {
			hideAndRelease()
			return
		}
		if active {
			tv.scrollToTop(animated: false)
			tv.tableHeaderView = searchBar
			tv.frame.origin.y = -searchBar.frame.height
			UIView.animate(withDuration: 0.3, animations: {
				tv.frame.origin.y =  0
			}) { _ in
				tv.reloadData()
				self.searchBar.becomeFirstResponder()
			}
		} else {
			searchBar.resignFirstResponder()
			UIView.animate(withDuration: 0.3, animations: {
				tv.frame.origin.y = -(tv.tableHeaderView?.frame.height ?? 0)
				tv.scrollToTop(animated: false) // false to let UIView animate the change
			}) { _ in
				tv.frame.origin.y = 0
				self.hideAndRelease()
				tv.reloadData()
			}
		}
	}
	
	/// Call `OnHide` closure (if set), then release strong closure references.
	private func hideAndRelease() {
		tableView?.tableHeaderView = nil
		onHideCallback?()
		onHideCallback = nil
		onChangeCallback = nil
	}
	
	
	// MARK: Search Bar Delegate
	
	func searchBarCancelButtonClicked(_ _: UISearchBar) {
		setSearchBarHidden(true)
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
	}
	
	func searchBar(_ _: UISearchBar, textDidChange _: String) {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
		perform(#selector(performSearch), with: nil, afterDelay: 0.2)
	}
	
	/// Internal callback function for delayed text evaluation.
	/// This way we can avoid unnecessary searches while user is typing.
	@objc private func performSearch() {
		onChangeCallback(searchBar.text ?? "")
		tableView?.reloadData()
	}
}
