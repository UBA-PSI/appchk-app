
precedencegroup CompareAssignPrecedence {
	assignment: true
	associativity: left
	higherThan: ComparisonPrecedence
}

infix operator <-? : CompareAssignPrecedence
infix operator <-/ : CompareAssignPrecedence

extension Equatable {
	/// Assign a new value to `lhs` if `newValue` differs from the previous value. Return `false` if they are equal.
	/// - Returns: `true` if `lhs` was overwritten with another value
	static func <-?(lhs: inout Self, newValue: Self) -> Bool {
		if lhs != newValue {
			lhs = newValue
			return true
		}
		return false
	}
	
	/// Assign a new value to `lhs` if `newValue` differs from the previous value.
	/// Return tuple with both values. Or `nil` if they are equal.
	/// - Returns: `nil` if `previousValue == newValue`
	static func <-/(lhs: inout Self, newValue: Self) -> (previousValue: Self, newValue: Self)? {
		let previousValue = lhs
		if previousValue != newValue {
			lhs = newValue
			return (previousValue, newValue)
		}
		return nil
	}
}
