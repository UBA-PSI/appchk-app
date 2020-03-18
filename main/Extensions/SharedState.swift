import Foundation

let dateTimeFormat = DateFormatter(withFormat: "yyyy-MM-dd  HH:mm:ss")
var currentVPNState: VPNState = .off

public enum VPNState : Int {
	case on = 1, inbetween, off
}
