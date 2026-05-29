import AppKit
import MacDogPrivilegedHelperSupport

@main
enum MacDogMain {
    static func main() {
        if CommandLine.arguments.dropFirst().first == "--verify-privileged-helper-xpc-read" {
            exit(verifyPrivilegedHelperXPCRead(arguments: Array(CommandLine.arguments.dropFirst())))
        }
        if CommandLine.arguments.dropFirst().first == "--verify-privileged-helper-xpc-set" {
            exit(verifyPrivilegedHelperXPCSet(arguments: Array(CommandLine.arguments.dropFirst())))
        }
        if CommandLine.arguments.dropFirst().first == "--verify-charge-limit-read" {
            exit(verifyChargeLimitRead(arguments: Array(CommandLine.arguments.dropFirst())))
        }
        if CommandLine.arguments.dropFirst().first == "--verify-charge-limit-set" {
            exit(verifyChargeLimitSet(arguments: Array(CommandLine.arguments.dropFirst())))
        }
        if CommandLine.arguments.dropFirst().first == "--set-login-item" {
            exit(setLoginItem(arguments: Array(CommandLine.arguments.dropFirst())))
        }
        if CommandLine.arguments.dropFirst().first == "--verify-login-item-status" {
            exit(verifyLoginItemStatus(arguments: Array(CommandLine.arguments.dropFirst())))
        }

        RunnerPreferences.registerDefaults()
        if SingleInstanceGuard.shouldTerminateCurrentInstance() {
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("MacDog sleep prevention must stay active while enabled.")
        ProcessInfo.processInfo.disableSuddenTermination()
        app.run()
    }

    private static func verifyPrivilegedHelperXPCRead(arguments: [String]) -> Int32 {
        let allowsMissing = arguments.contains("--allow-missing")
        let resultFile = optionValue(for: "--result-file", in: arguments)
        let snapshot = PrivilegedHelperInstallStateReader(
            fileChecker: FileManagerPrivilegedHelperFileChecker()
        ).snapshot()

        guard snapshot.status == .installed else {
            writeDiagnostic("helper-xpc:skipped status:\(snapshot.status.rawValue)", resultFile: resultFile)
            return allowsMissing ? 0 : 1
        }

        do {
            let helper = XPCClosedLidSleepHelperController(timeoutSeconds: 5)
            let sleepDisabled = try helper.readSleepDisabled()
            writeDiagnostic("helper-xpc:read SleepDisabled=\(sleepDisabled ? 1 : 0)", resultFile: resultFile)
            return 0
        } catch {
            writeDiagnostic("helper-xpc:error \(error.localizedDescription)", resultFile: resultFile)
            return 1
        }
    }

    private static func verifyPrivilegedHelperXPCSet(arguments: [String]) -> Int32 {
        let resultFile = optionValue(for: "--result-file", in: arguments)
        let shouldRestore = arguments.contains("--restore")
        guard let target = sleepDisabledValue(in: arguments) else {
            writeDiagnostic("helper-xpc:error missing set value", resultFile: resultFile)
            return 2
        }

        let snapshot = PrivilegedHelperInstallStateReader(
            fileChecker: FileManagerPrivilegedHelperFileChecker()
        ).snapshot()
        guard snapshot.status == .installed else {
            writeDiagnostic("helper-xpc:skipped status:\(snapshot.status.rawValue)", resultFile: resultFile)
            return 1
        }

        let helper = XPCClosedLidSleepHelperController(timeoutSeconds: 5)
        var original: Bool?

        do {
            original = try helper.readSleepDisabled()
            try helper.setSleepDisabled(target)
            let afterSet = try helper.readSleepDisabled()
            guard afterSet == target else {
                if shouldRestore, let original {
                    try? helper.setSleepDisabled(original)
                }
                writeDiagnostic(
                    "helper-xpc:error set verification failed expected=\(target ? 1 : 0) actual=\(afterSet ? 1 : 0)",
                    resultFile: resultFile
                )
                return 1
            }

            if shouldRestore, let original {
                try helper.setSleepDisabled(original)
                let restored = try helper.readSleepDisabled()
                guard restored == original else {
                    writeDiagnostic(
                        "helper-xpc:error restore verification failed expected=\(original ? 1 : 0) actual=\(restored ? 1 : 0)",
                        resultFile: resultFile
                    )
                    return 1
                }
                writeDiagnostic(
                    "helper-xpc:set SleepDisabled=\(target ? 1 : 0) before=\(original ? 1 : 0) after=\(afterSet ? 1 : 0) restored=\(restored ? 1 : 0)",
                    resultFile: resultFile
                )
            } else {
                writeDiagnostic(
                    "helper-xpc:set SleepDisabled=\(target ? 1 : 0) before=\(original.map { $0 ? 1 : 0 } ?? -1) after=\(afterSet ? 1 : 0)",
                    resultFile: resultFile
                )
            }
            return 0
        } catch {
            if shouldRestore, let original {
                try? helper.setSleepDisabled(original)
            }
            writeDiagnostic("helper-xpc:error \(error.localizedDescription)", resultFile: resultFile)
            return 1
        }
    }

    private static func optionValue(for option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }

    private static func setLoginItem(arguments: [String]) -> Int32 {
        let resultFile = optionValue(for: "--result-file", in: arguments)
        guard let rawEnabled = optionValue(for: "--enabled", in: arguments),
              let isEnabled = boolValue(rawEnabled) else {
            writeDiagnostic("login-item:error missing enabled value", resultFile: resultFile)
            return 2
        }

        do {
            try LoginLaunchController().setEnabled(isEnabled)
            writeDiagnostic("login-item:set enabled=\(isEnabled ? 1 : 0)", resultFile: resultFile)
            return 0
        } catch {
            writeDiagnostic("login-item:error \(error.localizedDescription)", resultFile: resultFile)
            return 1
        }
    }

    private static func verifyLoginItemStatus(arguments: [String]) -> Int32 {
        let resultFile = optionValue(for: "--result-file", in: arguments)
        let status = MainAppLoginLaunchService().status
        writeDiagnostic("login-item:status \(loginItemStatusLabel(status))", resultFile: resultFile)
        return status == .enabled ? 0 : 1
    }

    private static func loginItemStatusLabel(_ status: LoginLaunchStatus) -> String {
        switch status {
        case .notRegistered:
            return "notRegistered"
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requiresApproval"
        case .notFound:
            return "notFound"
        case .unknown:
            return "unknown"
        }
    }

    private static func sleepDisabledValue(in arguments: [String]) -> Bool? {
        if let value = optionValue(for: "--value", in: arguments) {
            return boolValue(value)
        }

        guard arguments.count > 1 else { return nil }
        return boolValue(arguments[1])
    }

    private static func boolValue(_ value: String) -> Bool? {
        switch value {
        case "1", "true", "on":
            true
        case "0", "false", "off":
            false
        default:
            nil
        }
    }

    private static func verifyChargeLimitRead(arguments: [String]) -> Int32 {
        let resultFile = optionValue(for: "--result-file", in: arguments)
        let state = NativeChargeLimitController().readState()
        guard state.isSupported else {
            writeDiagnostic("charge-limit:error \(state.errorMessage ?? "unsupported")", resultFile: resultFile)
            return 1
        }

        let limits = state.availableLimits.map(String.init).joined(separator: ",")
        let current = state.currentLimitPercent.map(String.init) ?? "unknown"
        writeDiagnostic("charge-limit:read current=\(current) available=\(limits)", resultFile: resultFile)
        return 0
    }

    private static func verifyChargeLimitSet(arguments: [String]) -> Int32 {
        let resultFile = optionValue(for: "--result-file", in: arguments)
        guard
            let rawValue = optionValue(for: "--value", in: arguments) ?? arguments.dropFirst().first,
            let target = Int(rawValue)
        else {
            writeDiagnostic("charge-limit:error missing target", resultFile: resultFile)
            return 2
        }

        let controller = NativeChargeLimitController()
        let before = controller.readState().currentLimitPercent
        let shouldRestore = arguments.contains("--restore")
        do {
            let applied = try controller.setLimitPercent(target)
            let after = controller.readState().currentLimitPercent
            var restored: Int?
            if shouldRestore, let before {
                _ = try controller.setLimitPercent(before)
                restored = controller.readState().currentLimitPercent
            }
            writeDiagnostic(
                "charge-limit:set target=\(target) applied=\(applied) before=\(before.map(String.init) ?? "unknown") after=\(after.map(String.init) ?? "unknown") restored=\(restored.map(String.init) ?? "not-requested")",
                resultFile: resultFile
            )
            if shouldRestore, let before {
                return restored == before ? 0 : 1
            }
            return after == applied ? 0 : 1
        } catch {
            writeDiagnostic("charge-limit:error \(error.localizedDescription)", resultFile: resultFile)
            return 1
        }
    }

    private static func writeDiagnostic(_ message: String, resultFile: String?) {
        print(message)

        guard let resultFile else { return }
        do {
            try message.appending("\n").write(toFile: resultFile, atomically: true, encoding: .utf8)
        } catch {
            fputs("helper-xpc:result-file-error \(error.localizedDescription)\n", stderr)
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

        if ProcessInfo.processInfo.environment["MACDOG_OPEN_POPOVER_ON_LAUNCH"] == "1" ||
            CommandLine.arguments.contains("--open-popover-on-launch") {
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
