import UIKit

extension CGContext {
	func lineFromTo(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) {
		self.move(to: CGPoint(x: x1, y: y1))
		self.addLine(to: CGPoint(x: x2, y: y2))
	}
}

struct BundleIcon {
	
	static let unknown : UIImage? = {
		let rect = CGRect(x: 0, y: 0, width: 30, height: 30)
		UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
		
		let context = UIGraphicsGetCurrentContext()!
		let lineWidth: CGFloat = 0.5
		let corner: CGFloat = 6.75
		let c = corner / CGFloat.pi + lineWidth/2
		let sz: CGFloat = rect.height
		let m = sz / 2
		let r1 = 0.2 * sz, r2 = sqrt(2 * r1 * r1)
		
		// diagonal
		context.lineFromTo(x1: c, y1: c, x2: sz-c, y2: sz-c)
		context.lineFromTo(x1: c, y1: sz-c, x2: sz-c, y2: c)
		// horizontal
		context.lineFromTo(x1: 0, y1: m, x2: sz, y2: m)
		context.lineFromTo(x1: 0, y1: m + r1, x2: sz, y2: m + r1)
		context.lineFromTo(x1: 0, y1: m - r1, x2: sz, y2: m - r1)
		// vertical
		context.lineFromTo(x1: m, y1: 0, x2: m, y2: sz)
		context.lineFromTo(x1: m + r1, y1: 0, x2: m + r1, y2: sz)
		context.lineFromTo(x1: m - r1, y1: 0, x2: m - r1, y2: sz)
		// circles
		context.addEllipse(in: CGRect(x: m - r1, y: m - r1, width: 2*r1, height: 2*r1))
		context.addEllipse(in: CGRect(x: m - r2, y: m - r2, width: 2*r2, height: 2*r2))
		let r3 = CGRect(x: c, y: c, width: sz - 2*c, height: sz - 2*c)
		context.addEllipse(in: r3)
		context.addRect(r3)
		
		UIColor.clear.setFill()
		UIColor.gray.setStroke()
		let rounded = UIBezierPath(roundedRect: rect.insetBy(dx: lineWidth/2, dy: lineWidth/2), cornerRadius: corner)
		rounded.lineWidth = lineWidth
		rounded.stroke()
		
		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return img
	}()
	
	private static let apple : UIImage? = {
		let rect = CGRect(x: 0, y: 0, width: 30, height: 30)
		UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
		
	//	#colorLiteral(red: 0.5843137503, green: 0.8235294223, blue: 0.4196078479, alpha: 1).setFill()
	//	UIBezierPath(roundedRect: rect, cornerRadius: 0).fill()
	//	print("drawing")
		let fs = 36 as CGFloat
		let hFont = UIFont.systemFont(ofSize: fs)
		var attrib = [
			NSAttributedString.Key.font: hFont,
			NSAttributedString.Key.foregroundColor: UIColor.gray
		]
		
		let str = "" as NSString
		let actualHeight = str.size(withAttributes: attrib).height
		attrib[NSAttributedString.Key.font] = hFont.withSize(fs * fs / actualHeight)
		
		let strW = str.size(withAttributes: attrib).width
		str.draw(at: CGPoint(x: (rect.size.width - strW) / 2.0, y: -3), withAttributes: attrib)
		
		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return img
	}()
	
	private static let cacheDir = URL.documentDir().appendingPathComponent("app-store-search-cache", isDirectory:true)
	
	private static func local(_ bundleId: String) -> URL {
		cacheDir.appendingPathComponent("\(bundleId).img")
	}
	
	static func initCache() {
		try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
	}
	
	static func image(_ bundleId: String?, ifNotStored: (() -> Void)? = nil) -> UIImage? {
		guard let appId = bundleId else {
			return unknown
		}
		guard let data = try? Data(contentsOf: local(appId)),
			let img = UIImage(data: data, scale: 2.0) else {
			ifNotStored?()
			return appId.hasPrefix("com.apple.") ? apple : unknown
		}
		return img
	}

	static func download(_ bundleId: String, url: URL, whenDone: @escaping () -> Void) -> URLSessionDownloadTask {
		return url.download(to: local(bundleId), onSuccess: whenDone)
	}
}
