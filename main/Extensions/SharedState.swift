import Foundation

var currentVPNState: VPNState = .off
let sync = SyncUpdate(periodic: 7)

public enum VPNState : Int {
	case on = 1, inbetween, off
}
