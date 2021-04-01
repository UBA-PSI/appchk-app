import UIKit
import AudioToolbox

protocol NotificationSoundChangedDelegate {
	/// Use `#mute` to disable sounds and `#default` to use default notification sound.
	func notificationSoundCurrent() -> String
	/// Called every time the user changes selection
	func notificationSoundChanged(filename: String, title: String)
}

class TVCChooseAlertTone: UITableViewController {
	
	var delegate: NotificationSoundChangedDelegate!
	private lazy var selected: String = delegate.notificationSoundCurrent()
	
	private func playTone(_ name: String) {
		switch name {
		case "#mute": return // No Sound
		case "#default": AudioServicesPlayAlertSound(1315) // Default sound
		default:
			guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
				preconditionFailure("Something went wrong. Sound file \(name).caf does not exist.")
			}
			var soundId: SystemSoundID = 0
			AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
			AudioServicesAddSystemSoundCompletion(soundId, nil, nil, { id, _ -> Void in
				AudioServicesDisposeSystemSoundID(id)
			}, nil)
			AudioServicesPlayAlertSound(soundId)
		}
	}
	
	
	// MARK: Table View Delegate
	
	override func numberOfSections(in _: UITableView) -> Int {
		AvailableSounds.count
	}
	
	override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
		AvailableSounds[section].count
	}
	
	override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
		section == 1 ? "AppChk" : nil
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsAlertToneCell")!
		let src = AvailableSounds[indexPath.section][indexPath.row]
		cell.textLabel?.text = src.title
		cell.accessoryType = (src.file == selected) ? .checkmark : .none
		return cell
	}
	
	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		let src = AvailableSounds[indexPath.section][indexPath.row]
		selected = src.file
		tableView.reloadData() // re-apply checkmarks
		playTone(selected)
		delegate.notificationSoundChanged(filename: src.file, title: src.title)
		return nil
	}
}

// MARK: - Sounds Data Source
// afconvert input.aiff output.caf -d ima4 -f caff -v

fileprivate let AvailableSounds: [[(title: String, file: String)]] = [
	[ // System sounds
		("None", "#mute"),
		("Default", "#default")
	], [ // AppChk sounds
		("Clock", "clock"),
		("Drum 1", "drum1"),
		("Drum 2", "drum2"),
		("Plop 1", "plop1"),
		("Plop 2", "plop2"),
		("Snap 1", "snap1"),
		("Snap 2", "snap2"),
		("Typewriter 1", "typewriter1"),
		("Typewriter 2", "typewriter2"),
		("Wood 1", "wood1"),
		("Wood 2", "wood2")
	]
]

func AlertSoundTitle(for filename: String) -> String {
	for section in AvailableSounds {
		for row in section {
			if row.file == filename {
				return row.title
			}
		}
	}
	return ""
}
