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
	
	private var searchNo = 0
	private var searchError: Bool = false
	private var downloadQueue: [URLSessionDownloadTask] = []
	
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
	
	private func showManualEntryAlert() {
		let alert = AskAlert(title: "App Name",
							 text: "Be as descriptive as possible. Preferably use app bundle id if available. Alternatively use app name or a link to a public repository.",
							 buttonText: "Set") {
			self.delegate?.appSearch(didSelect: "_manually", appName: $0.textFields?.first?.text, developer: nil)
			self.closeThis()
		}
		alert.addTextField { $0.placeholder = "com.apple.notes" }
		alert.presentIn(self)
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
					if searchError {
						cell.textLabel?.text = "Error loading results"
					} else if isLoading {
						cell.textLabel?.text = "Loading …"
					} else {
						cell.textLabel?.text = "No results"
					}
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
		
		let sno = searchNo
		cell.imageView?.image = BundleIcon.image(bundleId) {
			guard let u = altLoadUrl, let url = URL(string: u) else { return }
			self.downloadQueue.append(BundleIcon.download(bundleId, url: url) {
				DispatchQueue.main.async {
					// make sure its the same request
					guard sno == self.searchNo else { return }
					tableView.reloadRows(at: [indexPath], with: .automatic)
				}
			})
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
				showManualEntryAlert()
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
		for x in downloadQueue { x.cancel() }
		downloadQueue = []
		if searchText.count > 0 {
			perform(#selector(performSearch), with: nil, afterDelay: 0.4)
		} else {
			performSearch()
		}
	}
	
	/// Internal callback function for delayed text evaluation.
	/// This way we can avoid unnecessary searches while user is typing.
	@objc private func performSearch() {
		func setSource(_ newSource: [AppStoreSearch.Result], _ err: Bool) {
			searchNo += 1
			searchError = err
			dataSource = searchActive ? newSource : []
			tableView.reloadData()
		}
		isLoading = false
		let term = searchBar.text?.lowercased() ?? ""
		searchActive = term.count > 0
		guard searchActive else {
			setSource([], false)
			return
		}
		AppStoreSearch.search(term) { source, error in
			DispatchQueue.main.async {
				setSource(source ?? [], error != nil)
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
