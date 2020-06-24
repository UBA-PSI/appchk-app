import UIKit
import CoreGraphics

// MARK: White Triangle Popup Arrow

@IBDesignable
class PopupTriangle: UIView {
	@IBInspectable var rotation: CGFloat = 0
	@IBInspectable var color: UIColor = .black
	
	override func draw(_ rect: CGRect) {
		guard let c = UIGraphicsGetCurrentContext() else { return }
		let w = rect.width, h = rect.height
		switch rotation {
		case 90: // right
			c.lineFromTo(x1: 0, y1: 0, x2: w, y2: h/2)
			c.addLine(to: CGPoint(x: 0, y: h))
		case 180: // bottom
			c.lineFromTo(x1: w, y1: 0, x2: w/2, y2: h)
			c.addLine(to: CGPoint(x: 0, y: 0))
		case 270: // left
			c.lineFromTo(x1: w, y1: h, x2: 0, y2: h/2)
			c.addLine(to: CGPoint(x: w, y: 0))
		default: // top
			c.lineFromTo(x1: 0, y1: h, x2: w/2, y2: 0)
			c.addLine(to: CGPoint(x: w, y: h))
		}
		c.closePath()
		c.setFillColor(color.cgColor)
		c.fillPath()
	}
}


// MARK: Label as Tag Bubble

@IBDesignable
class TagLabel: UILabel {
	private var em: CGFloat { font.pointSize }
	@IBInspectable var padTop: CGFloat = 0
	@IBInspectable var padLeft: CGFloat = 0
	@IBInspectable var padRight: CGFloat = 0
	@IBInspectable var padBottom: CGFloat = 0
	private var padding: UIEdgeInsets {
		.init(top: padTop + em/6, left: padLeft + em/3,
			  bottom: padBottom + em/6, right: padRight + em/3)
	}
	
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
		let i = padding
		let ii = UIEdgeInsets(top: -i.top, left: -i.left, bottom: -i.bottom, right: -i.right)
		return super.textRect(forBounds: bounds.inset(by: i),
							  limitedToNumberOfLines: numberOfLines).inset(by: ii)
    }

    override func drawText(in rect: CGRect) {
		layer.masksToBounds = true
		layer.cornerRadius = em/2.5
		super.drawText(in: rect.inset(by: padding))
    }
}


// MARK: Percentage meter

@IBDesignable
class MeterBar: UIView {
	@IBInspectable var percent: CGFloat = 0 { didSet { setNeedsDisplay() } }
	@IBInspectable var barColor: UIColor = .sysFg
	@IBInspectable var horizontal: Bool = false
	
	private var normPercent: CGFloat { 1 - max(0, min(percent, 1)) }
	
	override func draw(_ rect: CGRect) {
		let c = UIGraphicsGetCurrentContext()
		c?.setFillColor(barColor.cgColor)
		if horizontal {
			c?.fill(rect.insetBy(dx: normPercent * (rect.width/2), dy: 0))
		} else {
			c?.fill(rect.insetBy(dx: 0, dy: normPercent * (rect.height/2)))
		}
	}
}
