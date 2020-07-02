import UIKit

extension UIView {
	func asImage(insets: UIEdgeInsets = .zero) -> UIImage {
		if #available(iOS 10.0, *) {
			let renderer = UIGraphicsImageRenderer(bounds: bounds.inset(by: insets))
			return renderer.image { rendererContext in
				layer.render(in: rendererContext.cgContext)
			}
		} else {
			UIGraphicsBeginImageContext(bounds.inset(by: insets).size)
			let ctx = UIGraphicsGetCurrentContext()!
			ctx.translateBy(x: -insets.left, y: -insets.top)
			layer.render(in:ctx)
			let image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			return UIImage(cgImage: image!.cgImage!)
		}
	}
	
	/// Find size that fits into frame with given `width` as precondition.
	/// - Parameter preferredHeight:If unset, find smallest possible size.
	func fittingSize(fixedWidth: CGFloat, preferredHeight: CGFloat = 0) -> CGSize {
		systemLayoutSizeFitting(CGSize(width: fixedWidth, height: preferredHeight), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
	}
	
	/// Find size that fits into frame with given `height` as precondition.
	/// - Parameter preferredWidth:If unset, find smallest possible size.
	func fittingSize(fixedHeight: CGFloat, preferredWidth: CGFloat = 0) -> CGSize {
		systemLayoutSizeFitting(CGSize(width: preferredWidth, height: fixedHeight), withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .required)
	}
}

extension UIEdgeInsets {
	init(all: CGFloat = 0, top: CGFloat? = nil, left: CGFloat? = nil, bottom: CGFloat? = nil, right: CGFloat? = nil) {
		self.init(top: top ?? all, left: left ?? all, bottom: bottom ?? all, right: right ?? all)
	}
}
