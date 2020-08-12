import UIKit

class VCShareRecording : UIViewController {
	
	var record: Recording!
	private var jsonData: Data?
	
	@IBOutlet private var text : UITextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let start = record.start
		let comp = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date(start))
		let wkYear = "\(comp.yearForWeekOfYear ?? 0).\(comp.weekOfYear ?? 0)"
		let lenSec = record.duration ?? 0
		
		let res = RecordingsDB.details(record)
		var cluster: [String : [Timestamp]] = [:]
		for (dom, ts) in res {
			if cluster[dom] == nil {
				cluster[dom] = []
			}
			cluster[dom]?.append(ts - start)
		}
		let domList = cluster.reduce("") {
			$0 + "\($1.key) : \($1.value.map{"\($0)"}.joined(separator: ", "))\n"
		}
		text.attributedText = NSMutableAttributedString()
			.h2("Review before sending\n")
			.normal("\nRead carefully. " +
				"You are about to upload the following information to our servers. " +
				"The data is anonymized in regards to device identifiers and time of recording. " +
				"It is however not anonymous to the domains requested during the recording." +
				"\n\n" +
				"If necessary, you can cancel this dialog and return to the recording overview. " +
				"Use swipe to delete individual domains." +
				"\n\n")
			.bold("Send to server:\n")
			.italic("\nDate: ", .callout).bold(wkYear, .callout)
			.italic("\nRec-Length: ", .callout).bold("\(lenSec) sec", .callout)
			.italic("\nApp-Bundle: ", .callout).bold(record.appId ?? "–", .callout)
			.italic("\nApp-Name: ", .callout).bold(record.title ?? "–", .callout)
			.italic("\n\n[domain name] : [relative time offsets]\n", .callout)
			.bold(domList, .callout)
		
		let json: [String : Any] = [
			"v" : 1,
			"date" : wkYear,
			"duration" : lenSec,
			"app-bundle" : record.appId ?? "",
			"app-name" : record.title ?? "",
			"logs" : cluster
			]
		jsonData = try? JSONSerialization.data(withJSONObject: json)
	}
	
	@IBAction private func closeView() {
		dismiss(animated: true)
	}
	
	@IBAction private func shareRecording() {
		print("\(String(data: jsonData!, encoding: .utf8)!)")
		Alert(title: "Not implemented yet", text: nil).presentIn(self)
	}
}
