import UIKit

class TVCDomains: UITableViewController, UISearchBarDelegate, FilterPipelineDelegate {
	
	lazy var source = GroupedDomainDataSource(withDelegate: self, parent: nil)
	
	private var searchActive: Bool = false
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
		searchBar.delegate = self
		NotifyDateFilterChanged.observe(call: #selector(didChangeDateFilter), on: self)
		didChangeDateFilter()
	}
	
	private var didLoadAlready = false
	override func viewDidAppear(_ animated: Bool) {
		if !didLoadAlready {
			didLoadAlready = true
			source.reloadFromSource()
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let index = tableView.indexPathForSelectedRow?.row {
			(segue.destination as? TVCHosts)?.parentDomain = source[index].domain
		}
	}
	
	
	// MARK: - Table View Data Source
	
	override func tableView(_ _: UITableView, numberOfRowsInSection _: Int) -> Int { source.numberOfRows }
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DomainCell")!
		let entry = source[indexPath.row]
		cell.textLabel?.text = entry.domain
		cell.detailTextLabel?.text = entry.detailCellText
		cell.imageView?.image = entry.options?.tableRowImage()
		return cell
	}
	
	func rowNeedsUpdate(_ row: Int) {
		let entry = source[row]
		let cell = tableView.cellForRow(at: IndexPath(row: row))
		cell?.detailTextLabel?.text = entry.detailCellText
		cell?.imageView?.image = entry.options?.tableRowImage()
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
		searchTerm = nil
		searchBar.text = nil
		tableView.tableHeaderView = hidden ? nil : searchBar
		if searchActive {
			source.pipeline.addFilter("search") {
				$0.domain.lowercased().contains(self.searchTerm ?? "")
			}
			searchBar.becomeFirstResponder()
		} else {
			source.pipeline.removeFilter(withId: "search")
		}
		tableView.reloadData()
	}
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
		perform(#selector(performSearch), with: nil, afterDelay: 0.2)
	}
	
	@objc private func performSearch() {
		searchTerm = searchBar.text?.lowercased() ?? ""
		source.pipeline.reloadFilter(withId: "search")
		tableView.reloadData()
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
	
	@objc private func didChangeDateFilter() {
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
