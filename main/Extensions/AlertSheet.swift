import UIKit

// MARK: Basic Alerts

/// - Parameters:
///   - buttonText: Default: "Dismiss"
func Alert(title: String?, text: String?, buttonText: String = "Dismiss") -> UIAlertController {
	let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
	alert.addAction(UIAlertAction(title: buttonText, style: .cancel, handler: nil))
	return alert
}

/// - Parameters:
///   - buttonText: Default: "Dismiss"
func ErrorAlert(_ error: Error, buttonText: String = "Dismiss") -> UIAlertController {
	return Alert(title: "Error", text: error.localizedDescription, buttonText: buttonText)
}

/// - Parameters:
///   - buttonText: Default: "Dismiss"
func ErrorAlert(_ errorDescription: String, buttonText: String = "Dismiss") -> UIAlertController {
	return Alert(title: "Error", text: errorDescription, buttonText: buttonText)
}

/// - Parameters:
///   - buttonText: Default: "Continue"
///   - buttonStyle: Default: `.default`
func AskAlert(title: String?, text: String?, buttonText: String = "Continue", buttonStyle: UIAlertAction.Style = .default, action: @escaping (UIAlertController) -> Void) -> UIAlertController {
	let alert = Alert(title: title, text: text, buttonText: "Cancel")
	alert.addAction(UIAlertAction(title: buttonText, style: buttonStyle) { _ in action(alert) })
	return alert
}

extension UIAlertController {
	func presentIn(_ viewController: UIViewController?) {
		viewController?.present(self, animated: true, completion: nil)
	}
}

// MARK: Alert with multiple options

func AlertWithOptions(title: String?, text: String?, buttons: [String], lastIsDestructive: Bool = false, callback: @escaping (_ index: Int?) -> Void) -> UIAlertController {
	let alert = UIAlertController(title: title, message: text, preferredStyle: .actionSheet)
	for (i, btn) in buttons.enumerated() {
		let dangerous = (lastIsDestructive && i + 1 == buttons.count)
		alert.addAction(UIAlertAction(title: btn, style: dangerous ? .destructive : .default) { _ in callback(i) })
	}
	alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in callback(nil) })
	return alert
}

func AlertDeleteLogs(_ domain: String, latest: Timestamp, success: @escaping (_ tsMin: Timestamp) -> Void) -> UIAlertController {
	let sinceNow = TimestampNow() - latest
	var buttons = ["Last 5 minutes", "Last 15 minutes", "Last hour", "Last 24 hours", "Delete everything"]
	var times: [Timestamp] = [300, 900, 3600, 86400]
	while times.count > 0, times[0] < sinceNow {
		buttons.removeFirst()
		times.removeFirst()
	}
	return AlertWithOptions(title: "Delete logs", text: "Delete logs for domain '\(domain)'", buttons: buttons, lastIsDestructive: true) {
		guard let idx = $0 else {
			return
		}
		if idx >= times.count {
			success(0)
		} else {
			success(Timestamp(Date().timeIntervalSince1970) - times[idx])
		}
	}
}
