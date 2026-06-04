import Foundation

struct UsageCacheRefreshCommand: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]

    init(
        codexUsageURL: URL,
        widgetBundled: Bool,
        requestTimeout: TimeInterval = CodexUsageCacheRefreshPolicy.requestTimeout
    ) {
        executableURL = codexUsageURL
        var arguments = [
            "status",
            "--write-cache",
            "--timeout",
            String(Int(requestTimeout))
        ]
        if widgetBundled {
            arguments.insert("--mirror-cache", at: 2)
        }
        self.arguments = arguments
    }
}

enum UsageCacheRefreshThrottle {
    static func shouldAttempt(
        lastAttempt: Date?,
        now: Date = Date(),
        force: Bool,
        minimumRetryInterval: TimeInterval = CodexUsageCacheRefreshPolicy.minimumRetryInterval
    ) -> Bool {
        if force {
            return true
        }
        guard let lastAttempt else {
            return true
        }
        return now.timeIntervalSince(lastAttempt) >= minimumRetryInterval
    }
}

enum UsageCacheRefreshBundleLocator {
    static func bundledCodexUsageURL(
        bundleURL: URL = Bundle.main.bundleURL,
        fileManager: FileManager = .default
    ) -> URL? {
        let url = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("codex-usage")
        return fileManager.isExecutableFile(atPath: url.path) ? url : nil
    }

    static func isWidgetBundled(
        relativeTo codexUsageURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let bundleURL = codexUsageURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let widgetURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("PlugIns", isDirectory: true)
            .appendingPathComponent("MacDogWidgetExtension.appex", isDirectory: true)
        return fileManager.fileExists(atPath: widgetURL.path)
    }
}

enum UsageCacheRefreshRunner {
    static func run(
        command: UsageCacheRefreshCommand,
        processTimeout: TimeInterval = CodexUsageCacheRefreshPolicy.processTimeout
    ) async {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = command.executableURL
            process.arguments = command.arguments
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                let deadline = Date().addingTimeInterval(processTimeout)
                while process.isRunning && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                if process.isRunning {
                    process.terminate()
                }
            } catch {
                return
            }
        }.value
    }
}
