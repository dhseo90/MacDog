import AppKit
import Foundation

struct RunningApplicationSnapshot: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?
    let bundleURLPath: String?
    let executableURLPath: String?
}

enum SingleInstanceGuard {
    static let appBundleIdentifier = "com.dhseo.macdog.MacDog"
    static let appName = "MacDog"

    static func duplicateApplication(
        in applications: [RunningApplicationSnapshot],
        currentProcessIdentifier: pid_t = getpid(),
        bundleIdentifier: String = appBundleIdentifier,
        appName: String = appName
    ) -> RunningApplicationSnapshot? {
        applications.first { application in
            application.processIdentifier != currentProcessIdentifier
                && application.isMacDogInstance(bundleIdentifier: bundleIdentifier, appName: appName)
        }
    }

    static func launchDecision(
        applications: [RunningApplicationSnapshot],
        currentProcessIdentifier: pid_t = getpid(),
        currentBundlePath: String? = Bundle.main.bundleURL.standardizedFileURL.path,
        bundleIdentifier: String = appBundleIdentifier,
        appName: String = appName
    ) -> SingleInstanceLaunchDecision {
        guard let duplicate = duplicateApplication(
            in: applications,
            currentProcessIdentifier: currentProcessIdentifier,
            bundleIdentifier: bundleIdentifier,
            appName: appName
        ) else {
            return .continueCurrent
        }

        guard
            let currentBundlePath,
            let duplicateBundlePath = duplicate.bundleURLPath,
            duplicateBundlePath != currentBundlePath
        else {
            return .terminateCurrent(activateProcessIdentifier: duplicate.processIdentifier)
        }

        return .terminateDuplicate(processIdentifier: duplicate.processIdentifier)
    }

    static func shouldTerminateCurrentInstance(
        currentProcessIdentifier: pid_t = getpid(),
        processIdentifierProvider: () -> [pid_t] = Self.macDogProcessIdentifiers
    ) -> Bool {
        processIdentifierProvider().contains { $0 != currentProcessIdentifier }
    }

    static func processIdentifiers(from output: String) -> [pid_t] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func macDogProcessIdentifiers() -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", appName]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return processIdentifiers(from: output)
    }
}

enum SingleInstanceLaunchDecision: Equatable {
    case continueCurrent
    case terminateCurrent(activateProcessIdentifier: pid_t)
    case terminateDuplicate(processIdentifier: pid_t)
}

private extension RunningApplicationSnapshot {
    func isMacDogInstance(bundleIdentifier: String, appName: String) -> Bool {
        if self.bundleIdentifier == bundleIdentifier {
            return true
        }

        if localizedName == appName, self.bundleIdentifier == nil {
            return true
        }

        return executableURLPath.map { URL(fileURLWithPath: $0).lastPathComponent == appName } ?? false
    }
}
