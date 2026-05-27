import AppKit

@main
@MainActor
final class MacDogWidgetHostApp: NSObject, NSApplicationDelegate {
    private static var delegate: MacDogWidgetHostApp?

    static func main() {
        let app = NSApplication.shared
        let delegate = MacDogWidgetHostApp()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.hide(nil)
    }
}
