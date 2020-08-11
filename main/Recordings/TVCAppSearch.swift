import UIKit

protocol TVCAppSearchDelegate {
	func appSearch(didSelect bundleId: String, appName: String?, developer: String?)
}

class TVCAppSearch: UITableViewController, UISearchBarDelegate {
	
	private var dataSource: [AppStoreSearch.Result] = []
	private var dataSourceLocal: [AppBundleInfo] = []
	private var isLoading: Bool = false
	private var searchActive: Bool = false
	var delegate: TVCAppSearchDelegate?
	
	@IBOutlet private var searchBar: UISearchBar!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		BundleIcon.initCache()
		dataSourceLocal = AppDB?.appBundleList() ?? []
	}
	
	override var keyCommands: [UIKeyCommand]? {
		[UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(closeThis))]
	}
	
	@objc private func closeThis() {
		searchBar.endEditing(true)
		dismiss(animated: true)
	}
	
	// MARK: - Table View Data Source
	
	override func numberOfSections(in _: UITableView) -> Int {
		dataSourceLocal.count > 0 ? 2 : 1
	}
	
	override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0: return max(1, dataSource.count) + (searchActive ? 1 : 0)
		case 1: return dataSourceLocal.count
		default: preconditionFailure()
		}
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0: return "AppStore"
		case 1: return "Found in other recordings"
		default: preconditionFailure()
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "AppStoreSearchCell")!
		let bundleId: String
		let altLoadUrl: String?
		
		switch indexPath.section {
		case 0:
			guard dataSource.count > 0, indexPath.row < dataSource.count else {
				if indexPath.row == 0 {
					cell.textLabel?.text = isLoading ? "Loading …" : "no results"
					cell.isUserInteractionEnabled = false
				} else {
					cell.textLabel?.text = "Create manually …"
				}
				cell.detailTextLabel?.text = nil
				cell.imageView?.image = nil
				return cell
			}
			let src = dataSource[indexPath.row]
			bundleId = src.bundleId
			altLoadUrl = src.imageURL
			cell.textLabel?.text = src.name
			cell.detailTextLabel?.text = src.developer
		case 1:
			let src = dataSourceLocal[indexPath.row]
			bundleId = src.bundleId
			altLoadUrl = nil
			cell.textLabel?.text = src.name
			cell.detailTextLabel?.text = src.author
		default:
			preconditionFailure()
		}
		
		cell.imageView?.image = BundleIcon.image(bundleId) {
			guard let url = altLoadUrl else { return }
			BundleIcon.download(bundleId, urlStr: url) {
				DispatchQueue.main.async {
					tableView.reloadRows(at: [indexPath], with: .automatic)
				}
			}
		}
		cell.isUserInteractionEnabled = true
		cell.imageView?.layer.cornerRadius = 6.75
		cell.imageView?.layer.masksToBounds = true
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		switch indexPath.section {
		case 0:
			guard indexPath.row < dataSource.count else {
				let alert = AskAlert(title: "App Name",
									 text: "Be as descriptive as possible. Preferably use app bundle id if available. Alternatively use app name or a link to a public repository.",
									 buttonText: "Set") {
					self.delegate?.appSearch(didSelect: "un.known", appName: $0.textFields?.first?.text, developer: nil)
					self.closeThis()
				}
				alert.addTextField { $0.placeholder = "com.apple.notes" }
				alert.presentIn(self)
				return
			}
			let src = dataSource[indexPath.row]
			delegate?.appSearch(didSelect: src.bundleId, appName: src.name, developer: src.developer)
		case 1:
			let src = dataSourceLocal[indexPath.row]
			delegate?.appSearch(didSelect: src.bundleId, appName: src.name, developer: src.author)
		default: preconditionFailure()
		}
		closeThis()
	}
	
	
	// MARK: - Search Bar Delegate
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
		isLoading = true
		tableView.reloadData()
		if searchText.count > 0 {
			perform(#selector(performSearch), with: nil, afterDelay: 0.4)
		} else {
			performSearch()
		}
	}
	
	/// Internal callback function for delayed text evaluation.
	/// This way we can avoid unnecessary searches while user is typing.
	@objc private func performSearch() {
		isLoading = false
		let term = searchBar.text?.lowercased() ?? ""
		searchActive = term.count > 0
		guard searchActive else {
			dataSource = []
			tableView.reloadData()
			return
		}
		AppStoreSearch.search(term) {
			self.dataSource = $0 ?? []
			DispatchQueue.main.async {
				self.tableView.reloadData()
			}
		}
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.endEditing(true)
	}
	
	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		closeThis()
	}
}
