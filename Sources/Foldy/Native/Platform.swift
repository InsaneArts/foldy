#if !os(watchOS)
import QuartzCore
#if canImport(UIKit)
import UIKit

/// The native view Foldy hosts and captures: `UIView` on iOS, `NSView` on macOS.
public typealias FoldPlatformView = UIView
/// The image a snapshot provider returns: `UIImage` on iOS, `NSImage` on macOS.
public typealias FoldPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit

/// The native view Foldy hosts and captures: `UIView` on iOS, `NSView` on macOS.
public typealias FoldPlatformView = NSView
/// The image a snapshot provider returns: `UIImage` on iOS, `NSImage` on macOS.
public typealias FoldPlatformImage = NSImage
#endif

@MainActor
enum FoldDisplayLink {
    /// A display link for the screen showing `view`, or the main screen.
    static func make(target: Any, selector: Selector, view: FoldPlatformView?) -> CADisplayLink? {
        #if canImport(UIKit)
        CADisplayLink(target: target, selector: selector)
        #else
        if let view, view.window != nil { return view.displayLink(target: target, selector: selector) }
        return NSScreen.main?.displayLink(target: target, selector: selector)
        #endif
    }
}
#endif
