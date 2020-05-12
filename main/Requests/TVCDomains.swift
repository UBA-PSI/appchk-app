import UIKit

class TVCDomains: UITableViewController, IncrementalDataSourceUpdate, UISearchBarDelegate {
	
	internal var dataSource: [GroupedDomain] = []
	private func dataSource(at: Int) -> GroupedDomain {
		dataSource[(searchActive ? searchIndices[at] : at)]
	}
	private var searchActive: Bool = false
	private var searchIndices: [Int] = []
	private var searchTerm: String?
	private let searchBar: UISearchBar = {
		let x = UISearchBar(frame: CGRect.init(x: 0, y: 0, width: 20, height: 10))
		x.sizeToFit()
		x.showsCancelButton = true
		x.autocapitalizationType = .none
		x.autocorrectionType = .no
		return x
	}()
	@IBOutlet private var filterButton: UIBarButtonItem!
	@IBOutlet private var filterButtonDetail: UIBarButtonItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if #available(iOS 10.0, *) {
			tableView.refreshControl = UIRefreshControl(call: #selector(reloadDataSource), on: self)
		}
		NotifyLogHistoryReset.observe(call: #selector(reloadDataSource), on: self)
		reloadDataSource()
		DBWrp.dataA_delegate = self
		searchBar.delegate = self
		NotifyDateFilterChanged.observe(call: #selector(dateFilterChanged), on: self)
		dateFilterChanged()
	}
	
	@objc func reloadDataSource() {
		dataSource = DBWrp.listOfDomains()
		if searchActive {
			searchBar(searchBar, textDidChange: "")
		} else {
			tableView.reloadData()
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			(segue.destination as? TVCHosts)?.parentDomain = dataSource(at: index).domain
		}
	}
	
	
	// MARK: - Table View Delegate
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int {
		searchActive ? searchIndices.count : dataSource.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DomainCell")!
		let entry = dataSource(at: indexPath.row)
		cell.textLabel?.text = entry.domain
		cell.detailTextLabel?.text = entry.detailCellText
		cell.imageView?.image = entry.options?.tableRowImage()
		return cell
	}
	
	
	// MARK: - Search
	
	@IBAction private func searchButtonTapped(_ sender: UIBarButtonItem) {
		setSearch(hidden: searchActive)
	}
	
	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		setSearch(hidden: true)
	}
	
	private func setSearch(hidden: Bool) {
		searchActive = !hidden
		searchIndices = []
		searchTerm = nil
		searchBar.text = nil
		tableView.tableHeaderView = hidden ? nil : searchBar
		if !hidden { searchBar.becomeFirstResponder() }
		tableView.reloadData()
	}
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
		perform(#selector(performSearch), with: nil, afterDelay: 0.3)
	}
	
	@objc private func performSearch() {
		searchTerm = searchBar.text?.lowercased() ?? ""
		searchIndices = dataSource.enumerated().compactMap {
			if $1.domain.lowercased().contains(searchTerm!) { return $0 }
			return nil
		}
		tableView.reloadData()
	}
	
	func shouldLiveUpdateIncrementalDataSource() -> Bool { !searchActive }
	
	func didUpdateIncrementalDataSource(_ operation: IncrementalDataSourceUpdateOperation, row: Int, moveTo: Int) {
		guard searchActive else {
			return
		}
		switch operation {
		case .ReloadTable:
			DispatchQueue.main.sync { tableView.reloadData() }
		case .Insert:
			if dataSource[row].domain.lowercased().contains(searchTerm ?? "") {
				searchIndices.insert(row, at: 0)
				DispatchQueue.main.sync { tableView.safeInsertRow(0, with: .left) }
			}
		case .Delete:
			if let idx = searchIndices.firstIndex(of: row) {
				searchIndices.remove(at: idx)
				DispatchQueue.main.sync { tableView.safeDeleteRow(idx) }
			}
		case .Update, .Move:
			if let idx = searchIndices.firstIndex(of: row) {
				if operation == .Move { searchIndices[idx] = moveTo }
				DispatchQueue.main.sync { tableView.safeReloadRow(idx) }
			}
		}
	}
	
	
	// MARK: - Filter
	
	@IBAction private func filterButtonTapped(_ sender: UIBarButtonItem) {
		let vc = self.storyboard!.instantiateViewController(withIdentifier: "domainFilter")
		vc.modalPresentationStyle = .custom
		if #available(iOS 13.0, *) {
			vc.isModalInPresentation = true
		}
		present(vc, animated: true)
	}
	
	@objc private func dateFilterChanged() {
		switch Pref.DateFilter.Kind {
		case .ABRange: // read start/end time
			self.filterButtonDetail.title = "A – B"
			self.filterButton.image = UIImage(named: "filter-filled")
		case .LastXMin: // most recent
			let lastXMin = Pref.DateFilter.LastXMin
			if lastXMin == 0 { fallthrough }
			self.filterButtonDetail.title = TimeFormat.short(minutes: lastXMin, style: .abbreviated)
			self.filterButton.image = UIImage(named: "filter-filled")
		default:
			self.filterButtonDetail.title = ""
			self.filterButton.image = UIImage(named: "filter-clear")
		}
	}
}
