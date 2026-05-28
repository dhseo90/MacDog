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

    @MainActor
    static func shouldTerminateCurrentInstance(
        workspace: NSWorkspace = .shared,
        currentProcessIdentifier: pid_t = getpid()
    ) -> Bool {
        let applications = workspace.runningApplications.map {
            RunningApplicationSnapshot(
                processIdentifier: $0.processIdentifier,
                bundleIdentifier: $0.bundleIdentifier,
                localizedName: $0.localizedName,
                bundleURLPath: $0.bundleURL?.standardizedFileURL.path,
                executableURLPath: $0.executableURL?.standardizedFileURL.path
            )
        }

        let decision = launchDecision(
            applications: applications,
            currentProcessIdentifier: currentProcessIdentifier
        )

        switch decision {
        case .continueCurrent:
            return false
        case .terminateCurrent(let processIdentifier):
            workspace.runningApplications
                .first { $0.processIdentifier == processIdentifier }?
                .activate(options: [])
            return true
        case .terminateDuplicate(let processIdentifier):
            workspace.runningApplications
                .first { $0.processIdentifier == processIdentifier }?
                .terminate()
            return false
        }
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
