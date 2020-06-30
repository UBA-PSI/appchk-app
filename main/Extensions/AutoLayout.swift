import UIKit

/*
  Readable Auto Layout Constraints

  Usage:
    A.anchor =&= multiplier * B.anchor + constant | priority
*/

infix operator =&= : AdditionPrecedence
infix operator =<= : AdditionPrecedence
infix operator =>= : AdditionPrecedence
//infix operator | : AdditionPrecedence

/// Create and activate an `equal` constraint between left and right anchor. Format: `A.anchor =&= multiplier * B.anchor + constant | priority`
@discardableResult func =&= <T>(l: NSLayoutAnchor<T>, r: NSLayoutAnchor<T>) -> NSLayoutConstraint { l.constraint(equalTo: r).on() }
/// Create and activate a `lessThan` constraint between left and right anchor. Format: `A.anchor =<= multiplier * B.anchor + constant | priority`
@discardableResult func =<= <T>(l: NSLayoutAnchor<T>, r: NSLayoutAnchor<T>) -> NSLayoutConstraint { l.constraint(lessThanOrEqualTo: r).on() }
/// Create and activate a `greaterThan` constraint between left and right anchor. Format: `A.anchor =>= multiplier * B.anchor + constant | priority`
@discardableResult func =>= <T>(l: NSLayoutAnchor<T>, r: NSLayoutAnchor<T>) -> NSLayoutConstraint { l.constraint(greaterThanOrEqualTo: r).on() }

extension NSLayoutDimension { // higher precedence, so multiply first
	/// Create intermediate anchor multiplier result.
	static func *(l: CGFloat, r: NSLayoutDimension) -> AnchorMultiplier { .init(anchor: r, m: l) }
}

/// Intermediate `NSLayoutConstraint` anchor with multiplier supplement
struct AnchorMultiplier {
	let anchor: NSLayoutDimension, m: CGFloat
	
	/// Create and activate an `equal` constraint between left and right anchor. Format: `A.anchor =&= multiplier * B.anchor + constant | priority`
	@discardableResult static func =&=(l: NSLayoutDimension, r: Self) -> NSLayoutConstraint { l.constraint(equalTo: r.anchor, multiplier: r.m).on() }
	/// Create and activate a `lessThan` constraint between left and right anchor. Format: `A.anchor =<= multiplier * B.anchor + constant | priority`
	@discardableResult static func =<=(l: NSLayoutDimension, r: Self) -> NSLayoutConstraint { l.constraint(lessThanOrEqualTo: r.anchor, multiplier: r.m).on() }
	/// Create and activate a `greaterThan` constraint between left and right anchor. Format: `A.anchor =>= multiplier * B.anchor + constant | priority`
	@discardableResult static func =>=(l: NSLayoutDimension, r: Self) -> NSLayoutConstraint { l.constraint(greaterThanOrEqualTo: r.anchor, multiplier: r.m).on() }
}

extension NSLayoutConstraint {
	/// Change `isActive`to `true` and return `self`
	func on() -> Self { isActive = true; return self }
	/// Change `constant`attribute  and return `self`
	@discardableResult static func +(l: NSLayoutConstraint, r: CGFloat) -> NSLayoutConstraint { l.constant = r; return l }
	/// Change `constant` attribute and return `self`
	@discardableResult static func -(l: NSLayoutConstraint, r: CGFloat) -> NSLayoutConstraint { l.constant = -r; return l }
	/// Change `priority` attribute and return `self`
	@discardableResult static func |(l: NSLayoutConstraint, r: UILayoutPriority) -> NSLayoutConstraint { l.priority = r; return l }
}

extension NSLayoutDimension {
	/// Create and activate an `equal` constraint with constant value. Format: `A.anchor =&= constant | priority`
	@discardableResult static func =&= (l: NSLayoutDimension, r: CGFloat) -> NSLayoutConstraint { l.constraint(equalToConstant: r).on() }
	/// Create and activate a `lessThan` constraint with constant value. Format: `A.anchor =<= constant | priority`
	@discardableResult static func =<= (l: NSLayoutDimension, r: CGFloat) -> NSLayoutConstraint { l.constraint(lessThanOrEqualToConstant: r).on() }
	/// Create and activate a `greaterThan` constraint with constant value. Format: `A.anchor =>= constant | priority`
	@discardableResult static func =>= (l: NSLayoutDimension, r: CGFloat) -> NSLayoutConstraint { l.constraint(greaterThanOrEqualToConstant: r).on() }
}

/*
  UIView extension to generate multiple constraints at once

  Usage:
    child.anchor([.width, .height], to: parent) | .defaultLow
*/

extension UIView {
	/// Edges that need the relation to flip arguments. For these we need to inverse the constant value and relation.
	private static let inverseItem: [NSLayoutConstraint.Attribute] = [.right, .bottom, .trailing, .lastBaseline, .rightMargin, .bottomMargin, .trailingMargin]
	
	/// Create and active constraints for provided edges. Constraints will anchor the same edge on both `self` and `other`.
	/// - Note: Will set `translatesAutoresizingMaskIntoConstraints = false`
	/// - Parameters:
	///   - edges: List of constraint attributes, e.g. `[.top, .bottom, .left, .right]`
	///   - other: Instance to bind to, e.g. `UIView` or `UILayoutGuide`
	///   - margin: Used as constant value. Multiplier will always be `1.0`. If you need to change the multiplier, use single constraints instead. (Default: `0`)
	///   - rel: Constraint relation. (Default: `.equal`)
	/// - Returns: List of created and active constraints
	@discardableResult func anchor(_ edges: [NSLayoutConstraint.Attribute], to other: Any, margin: CGFloat = 0, if rel: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
		translatesAutoresizingMaskIntoConstraints = false
		return edges.map {
			let (A, B) = UIView.inverseItem.contains($0) ? (other, self) : (self, other)
			return NSLayoutConstraint(item: A, attribute: $0, relatedBy: rel, toItem: B, attribute: $0, multiplier: 1, constant: margin).on()
		}
	}
	
	/// Sets the priority with which a view resists being made smaller and larger than its intrinsic size.
	func constrainHuggingCompression(_ axis: NSLayoutConstraint.Axis, _ priotity: UILayoutPriority) {
		setContentHuggingPriority(priotity, for: axis)
		setContentCompressionResistancePriority(priotity, for: axis)
	}
}

extension Array where Element: NSLayoutConstraint {
	/// set `priority` on all elements and return same list
	@discardableResult static func |(l: Self, r: UILayoutPriority) -> Self {
		for x in l { x.priority = r }
		return l
	}
}
