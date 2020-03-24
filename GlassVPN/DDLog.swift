import Foundation

// MARK: Third party dependencies
//
// Removed unnecessary parts of NEKit to keep the dependency chain small.
// Omitting embeded frameworks; which aren't allowed in NetworkExtensions?
//
// 0.15.0 https://github.com/zhuhaow/NEKit/commit/f09ba8aef1e70881edf0578d23c04d88cc706f52
// 0.3.0  https://github.com/zhuhaow/Resolver/commit/5d08fd52822d1f9217019ae8867e78daa48f667c
// 7.6.4  https://github.com/robbiehanson/CocoaAsyncSocket/commit/0e00c967a010fc43ce528bd633d032f17158d393


// MARK: DDLog

#if DEBUG
@inlinable public func DDLogVerbose(_ message: String) { NSLog("[VPN.VERBOSE] " + message) }
@inlinable public func DDLogDebug(_ message: String) { NSLog("[VPN.DEBUG] " + message) }
#else
@inlinable public func DDLogVerbose(_ _: String) {}
@inlinable public func DDLogDebug(_ _: String) {}
#endif
@inlinable public func DDLogInfo(_ message: String) { NSLog("[VPN.INFO] " + message) }
@inlinable public func DDLogWarn(_ message: String) { NSLog("[VPN.WARN] " + message) }
@inlinable public func DDLogError(_ message: String) { NSLog("[VPN.ERROR] " + message) }
