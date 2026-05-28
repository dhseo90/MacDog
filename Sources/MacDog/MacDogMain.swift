import AppKit

@main
enum MacDogMain {
    static func main() {
        RunnerPreferences.registerDefaults()
        if SingleInstanceGuard.shouldTerminateCurrentInstance() {
            return
        }

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

        if ProcessInfo.processInfo.environment["MACDOG_OPEN_POPOVER_ON_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                controller.showUsagePopover()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { ["macdog", "codexusage"].contains($0.scheme) }) else { return }
        controller?.showUsagePopover()
    }
}
