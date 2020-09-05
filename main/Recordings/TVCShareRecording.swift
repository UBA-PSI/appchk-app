import UIKit

class TVCShareRecording : UITableViewController, UITextViewDelegate, VCEditTextDelegate {
	
	@IBOutlet private var sendButton: UIBarButtonItem!
	
	// vars
	var record: Recording!
	private var shareNotes: Bool = false // opt-in
	private lazy var hasNotes: Bool = (self.record.notes != nil)
	private lazy var editedNotes: String = self.record.notes ?? ""
	private lazy var weekInYear: String = {
		let comp = Calendar.current.dateComponents(
			[.weekOfYear, .yearForWeekOfYear], from: Date(self.record.start))
		return "\(comp.yearForWeekOfYear ?? 0).\(comp.weekOfYear ?? 0)"
	}()
	
	// Data source
	private lazy var dataSource: [String : [Timestamp]] = RecordingsDB.detailCluster(self.record)
	
	private lazy var dataSourceKeyValue: [(key: String, value: String)] = [
		("Date",       self.weekInYear),
		("Rec-Length", "\(self.record.duration) sec"),
		("App-Bundle", self.record.appId ?? " – "),
		("App-Name",   self.record.title ?? " – "),
		("Notes",      " – ") // see delegate below
	]
	
	private lazy var dataSourceLogs: [(domain: String, occurrences: String, enabled: Bool)] = self.dataSource.map {
		($0.key, $0.value.map{"\($0)"}.joined(separator: ", "), true)
	}.sorted(by: { $0.domain < $1.domain })
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if record.isShared {
			sendButton.tintColor = .gray
		}
	}
	
	private func reloadNotes() {
		tableView.reloadRows(at: [
			IndexPath(row: 0, section: 1), // edit field
			IndexPath(row: 4, section: 2) // display field
		], with: .automatic)
	}
	
	
	// MARK: - User Interaction
	
	@IBAction private func didChangeNotesCheckbox(_ sender: UISwitch) {
		shareNotes = sender.isOn
		reloadNotes()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let dest = segue.destination as? VCEditText {
			dest.text = editedNotes
			dest.delegate = self
		}
	}
	
	func editText(didFinish text: String) {
		editedNotes = text
		reloadNotes()
	}
	
	@IBAction private func shareRecording(_ sender: UIBarButtonItem) {
		guard !record.isShared else {
			showAlertAlreadyShared()
			return
		}
		navigationItem.rightBarButtonItem = {
			let v = UIView()
			let activity = UIActivityIndicatorView()
			v.addSubview(activity)
			activity.anchor([.centerX, .centerY], to: v)
			activity.startAnimating()
			v.widthAnchor =&= 2 * activity.widthAnchor
			return UIBarButtonItem(customView: v)
		}()
		
		postToServer() { [weak self] in
			self?.navigationItem.rightBarButtonItem = self?.sendButton
		}
	}
	
	
	// MARK: - Table Data Source
	
	override func numberOfSections(in _: UITableView) -> Int { 4 }
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0: return 1 // description
		case 1: return hasNotes ? 2 : 0 // notes + checkbox
		case 2: return dataSourceKeyValue.count
		case 3: return dataSourceLogs.count
		default: preconditionFailure()
		}
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0: return "Review before sending"
		case 1: return hasNotes ? "Notes" : nil
		case 2: return "Send to server"
		case 3: return "Logs"
		default: return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		switch section {
		case 0: return "You can tap on a domain cell to exclude it from the upload."
		case 2: return "Below you see the domain names, followed by a list of relative time offsets (in seconds)."
		default: return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: UITableViewCell
		switch indexPath.section {
		case 0:
			cell = tableView.dequeueReusableCell(withIdentifier: "shareTextCell")!
			cell.textLabel?.text = """
				You are about to upload the following information to our servers.
				The data is anonymized in regards to device identifiers and time of recording. However, it is not anonymous to the domains requested during the recording.
				"""
		case 1:
			switch indexPath.row {
			case 0:
				cell = tableView.dequeueReusableCell(withIdentifier: "shareOpenTextCell")!
				cell.textLabel?.text = editedNotes
				cell.textLabel?.textColor = shareNotes ? nil : .gray
			case 1:
				cell = tableView.dequeueReusableCell(withIdentifier: "shareCheckboxCell")!
				cell.textLabel?.text = "Upload your notes?"
				let accessory = cell.accessoryView as! UISwitch
				accessory.isOn = shareNotes
			default: preconditionFailure()
			}
		case 2:
			cell = tableView.dequeueReusableCell(withIdentifier: "shareKeyValueCell")!
			let src = dataSourceKeyValue[indexPath.row]
			cell.textLabel?.text = src.key
			let flag = shareNotes && indexPath.row == 4
			cell.detailTextLabel?.text = flag ? editedNotes : src.value
		case 3:
			cell = tableView.dequeueReusableCell(withIdentifier: "shareLogCell")!
			let src = dataSourceLogs[indexPath.row]
			let sent = src.enabled
			cell.textLabel?.text = src.domain
			cell.detailTextLabel?.text = sent ? src.occurrences : "don't upload"
			cell.accessoryType = sent ? .checkmark : .none
			cell.textLabel?.isEnabled = sent
			cell.detailTextLabel?.isEnabled = sent
		default:
			preconditionFailure()
		}
		if #available(iOS 11, *) {} else {
			cell.detailTextLabel?.numberOfLines = 1
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard indexPath.section == 3 else { return }
		dataSourceLogs[indexPath.row].enabled = !dataSourceLogs[indexPath.row].enabled
		tableView.deselectRow(at: indexPath, animated: true)
		tableView.reloadRows(at: [indexPath], with: .automatic)
	}
	
	
	// MARK: - Upload
	
	private func postToServer(_ onceLoaded: @escaping () -> Void) {
		// prepare json
		let allowed = dataSourceLogs.filter{ $0.enabled }.map{ $0.domain }
		let json = try? JSONSerialization.data(withJSONObject: [
			"v" : 1,
			"date" : weekInYear,
			"duration" : record.duration,
			"app-bundle" : record.appId ?? "",
			"app-name" : record.title ?? "",
			"notes" : shareNotes ? editedNotes : "",
			"logs" : dataSource.filter{ allowed.contains($0.key) }
		])
		
		// prepare post request
		let url = URL(string: "https://appchk.de/api/v1/contribute/")!
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = json
		var rec = record! // store temporarily so self can be released
		
		// send to server
		URLSession.shared.dataTask(with: request) { data, response, error in
			DispatchQueue.main.async { [weak self] in
				onceLoaded()
				guard error == nil, let data = data,
					let response = response as? HTTPURLResponse else {
					self?.banner(.fail, "\(error?.localizedDescription ?? "Unkown error occurred")")
					return
				}
				guard let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
					let v = json["v"] as? Int, v > 0 else {
					QLog.Warning("Couldn't contribute: Not JSON or no version key")
					self?.banner(.fail, "Server couldn't parse request.\nTry again later.")
					return
				}
				let status = json["status"] as? String ?? "unkown reason"
				guard status == "ok", (200 ... 299) ~= response.statusCode else {
					QLog.Warning("Couldn't contribute: \(status)")
					self?.banner(.fail, "Error: \(status)")
					return
				}
				// update db, mark record as shared
				rec.uploadkey = json["key"] as? String ?? "_"
				self?.record = rec // in case view is still open
				RecordingsDB.update(rec) // rec cause self may not be available
				self?.sendButton.tintColor = .gray
				// notify user about results
				if v == 1, let urlStr = json["url"] as? String {
					let nextUpdateIn = json["when"] as? Int
					self?.showAlertAvailableSoon(urlStr, when: nextUpdateIn)
				}
				self?.banner(.ok, "Thank you for your contribution.")
			}
		}.resume()
	}
	
	
	// MARK: - Alerts & Banner
	
	private func banner(_ style: NotificationBanner.Style, _ msg: String) {
		NotificationBanner(msg, style: style).present(in: self)
	}
	
	private func showAlertAvailableSoon(_ urlStr: String, when: Int?) {
		var msg = "Your contribution is being processed and will be available "
		if let when = when {
			if when < 61 {
				msg += "in approx. \(when) sec. "
			} else {
				let fmt = TimeFormat.from(Timestamp(when))
				msg += "in \(fmt) min. "
			}
		} else {
			msg += "shortly. "
		}
		msg += "Open results webpage now?"
		AskAlert(title: "Thank you", text: msg, buttonText: "Show results", cancelButton: "Not now") { _ in
			if let url = URL(string: urlStr) {
				UIApplication.shared.openURL(url)
			}
		}.presentIn(self)
	}
	
	private func showAlertAlreadyShared() {
		let alert = Alert(title: nil, text: "You already shared this recording.")
		if let bid = record.appId, bid.isValidBundleId() {
			alert.addAction(UIAlertAction.init(title: "Open results", style: .default, handler: { _ in
				URL(string: "https://appchk.de/redirect.html?id=\(bid)")?.open()
			}))
		}
		alert.presentIn(self)
	}
}
