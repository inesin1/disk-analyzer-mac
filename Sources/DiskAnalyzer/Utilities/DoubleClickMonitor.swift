import AppKit

/// App-wide double click hook. SwiftUI's `TapGesture(count: 2)` does not fire inside `List`
/// rows, so double clicks are picked up straight from the event stream instead.
enum DoubleClickMonitor {
    private static var installed = false
    private static var handler: ((NSEvent) -> Void)?

    static func install(_ callback: @escaping (NSEvent) -> Void) {
        handler = callback
        guard !installed else { return }
        installed = true

        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if event.clickCount == 2 {
                handler?(event)
            }
            return event  // Returning the event keeps normal clicks working.
        }
    }
}
