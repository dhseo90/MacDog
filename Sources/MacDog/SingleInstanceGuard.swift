import AppKit
import Foundation

struct RunningApplicationSnapshot: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?
}

enum SingleInstanceGuard {
    static let appBundleIdentifier = "com.dhseo.macdog.MacDog"

    static func duplicateApplication(
        in applications: [RunningApplicationSnapshot],
        currentProcessIdentifier: pid_t = getpid(),
        bundleIdentifier: String = appBundleIdentifier
    ) -> RunningApplicationSnapshot? {
        applications.first { application in
            application.processIdentifier != currentProcessIdentifier &&
            application.bundleIdentifier == bundleIdentifier
        }
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
                localizedName: $0.localizedName
            )
        }
        guard let duplicate = duplicateApplication(
            in: applications,
            currentProcessIdentifier: currentProcessIdentifier
        ) else {
            return false
        }

        workspace.runningApplications
            .first { $0.processIdentifier == duplicate.processIdentifier }?
            .activate(options: [])
        return true
    }
}
