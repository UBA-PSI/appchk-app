import UIKit

class SearchBarManager: NSObject, UISearchResultsUpdating {
	
	private(set) var isActive = false
	private(set) var term = ""
	private lazy var controller: UISearchController = {
		let x = UISearchController(searchResultsController: nil)
		x.searchBar.autocapitalizationType = .none
		x.searchBar.autocorrectionType = .no
		x.obscuresBackgroundDuringPresentation = false
		x.searchResultsUpdater = self
		return x
	}()
	private weak var tvc: UITableViewController?
	private let onChangeCallback: (String) -> Void
	
	/// Prepare `UISearchBar` for user input
	/// - Parameter onChange: Code that will be executed every time the user changes the text (with 0.2s delay)
	required init(onChange: @escaping (String) -> Void) {
		onChangeCallback = onChange
		super.init()
		
		UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
			.defaultTextAttributes = [.font: UIFont.preferredFont(forTextStyle: .body)]
	}
	
	/// Assigns the `UISearchBar` to `tableView.tableHeaderView` (iOS 9) or `navigationItem.searchController` (iOS 11).
	func fuseWith(tableViewController: UITableViewController?) {
		guard tvc !== tableViewController else { return }
		tvc = tableViewController
		
		if #available(iOS 11.0, *) {
			tvc?.navigationItem.searchController = controller
		} else {
			controller.loadViewIfNeeded() // Fix: "Attempting to load the view of a view controller while it is deallocating"
			tvc?.definesPresentationContext = true // make search bar disappear if user changes scene (eg. select cell)
			//tvc?.tableView.backgroundView = UIView() // iOS 11+ bug: bright white background in dark mode
			tvc?.tableView.tableHeaderView = controller.searchBar
			tvc?.tableView.setContentOffset(.init(x: 0, y: controller.searchBar.frame.height), animated: false)
		}
	}
	
	/// Search callback
	func updateSearchResults(for controller: UISearchController) {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
		perform(#selector(performSearch), with: nil, afterDelay: 0.2)
	}
	
	/// Internal callback function for delayed text evaluation.
	/// This way we can avoid unnecessary searches while user is typing.
	@objc private func performSearch() {
		term = controller.searchBar.text?.lowercased() ?? ""
		isActive = term.count > 0
		onChangeCallback(term)
	}
}
