import UIKit

enum ProxyState {
	case stopped, unkown, running
}

@IBDesignable
class DotState: UIImage {
	var status: ProxyState = .stopped // { didSet { }}
	
	override func draw(in rect: CGRect) {
		let pt = CGPoint(x: rect.midX, y: rect.midY)
		let r = min(rect.size.width, rect.size.height) / 2.0 * 0.6
		switch status {
			case .stopped: #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1).setFill()
			case .unkown:  #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1).setFill()
			case .running: #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1).setFill()
		}
		UIBezierPath(arcCenter: pt, radius: r, startAngle: 0, endAngle: 10, clockwise: true).fill()
	}
}


