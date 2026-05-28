import AppKit
import MacDogPrivilegedHelperSupport

@main
enum MacDogMain {
    static func main() {
        if CommandLine.arguments.dropFirst().first == "--verify-privileged-helper-xpc-read" {
            exit(verifyPrivilegedHelperXPCRead(arguments: Array(CommandLine.arguments.dropFirst())))
        }

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

    private static func verifyPrivilegedHelperXPCRead(arguments: [String]) -> Int32 {
        let allowsMissing = arguments.contains("--allow-missing")
        let snapshot = PrivilegedHelperInstallStateReader(
            fileChecker: FileManagerPrivilegedHelperFileChecker()
        ).snapshot()

        guard snapshot.status == .installed else {
            print("helper-xpc:skipped status:\(snapshot.status.rawValue)")
            return allowsMissing ? 0 : 1
        }

        do {
            let helper = XPCClosedLidSleepHelperController(timeoutSeconds: 5)
            let sleepDisabled = try helper.readSleepDisabled()
            print("helper-xpc:read SleepDisabled=\(sleepDisabled ? 1 : 0)")
            return 0
        } catch {
            print("helper-xpc:error \(error.localizedDescription)")
            return 1
        }
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
