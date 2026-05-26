import AppKit

@main
enum CodexUsageMonitorMain {
    static func main() {
        RunnerPreferences.registerDefaults()

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MenuBarController()
        controller.start()
        self.controller = controller
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "codexusage" }) else { return }
        controller?.showUsagePopover()
    }
}
