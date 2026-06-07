import AppKit
import Foundation

struct InstallerCleanupPlan: Equatable {
    let mountedInstallerVolumes: [URL]
    let downloadedInstallerFiles: [URL]

    var isEmpty: Bool {
        mountedInstallerVolumes.isEmpty && downloadedInstallerFiles.isEmpty
    }

    var summary: String {
        var parts: [String] = []
        if !mountedInstallerVolumes.isEmpty {
            parts.append("설치 디스크 \(mountedInstallerVolumes.count)개")
        }
        if !downloadedInstallerFiles.isEmpty {
            parts.append("다운로드 파일 \(downloadedInstallerFiles.count)개")
        }
        return parts.isEmpty ? "정리할 설치 파일이 없습니다." : parts.joined(separator: ", ")
    }

    fileprivate var promptSignature: String {
        let volumeParts = mountedInstallerVolumes
            .map { "volume:\($0.standardizedFileURL.path)" }
            .sorted()
        let fileParts = downloadedInstallerFiles
            .map { "file:\($0.standardizedFileURL.path)" }
            .sorted()
        return (volumeParts + fileParts).joined(separator: "\n")
    }
}

struct InstallerCleanupController {
    static let promptDismissedKey = "installerCleanupPromptDismissed"
    private static let promptDismissedPlanSignatureKey = "installerCleanupPromptDismissedPlanSignature"

    private let homeDirectory: URL
    private let fileManager: FileManager
    private let mountedVolumeProvider: () -> [URL]
    private let detachVolumeHandler: (URL) throws -> Void

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        mountedVolumeProvider: (() -> [URL])? = nil,
        detachVolumeHandler: ((URL) throws -> Void)? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
        self.mountedVolumeProvider = mountedVolumeProvider ?? {
            fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: [.volumeNameKey],
                options: [.skipHiddenVolumes]
            ) ?? []
        }
        self.detachVolumeHandler = detachVolumeHandler ?? Self.detachVolume(at:)
    }

    func cleanupPlan() -> InstallerCleanupPlan {
        InstallerCleanupPlan(
            mountedInstallerVolumes: mountedInstallerVolumes(),
            downloadedInstallerFiles: downloadedInstallerFiles()
        )
    }

    func cleanupPromptPlan() -> InstallerCleanupPlan {
        InstallerCleanupPlan(
            mountedInstallerVolumes: mountedInstallerVolumes(),
            downloadedInstallerFiles: []
        )
    }

    static func shouldShowPrompt(
        for plan: InstallerCleanupPlan,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !plan.isEmpty else { return false }
        return defaults.string(forKey: promptDismissedPlanSignatureKey) != plan.promptSignature
    }

    static func recordPromptDismissed(
        for plan: InstallerCleanupPlan,
        defaults: UserDefaults = .standard
    ) {
        guard !plan.isEmpty else {
            clearPromptDismissal(defaults: defaults)
            return
        }

        defaults.set(true, forKey: promptDismissedKey)
        defaults.set(plan.promptSignature, forKey: promptDismissedPlanSignatureKey)
    }

    static func clearPromptDismissal(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: promptDismissedKey)
        defaults.removeObject(forKey: promptDismissedPlanSignatureKey)
    }

    func cleanup(_ plan: InstallerCleanupPlan) throws {
        var failures: [String] = []

        for fileURL in plan.downloadedInstallerFiles {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                failures.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        for volumeURL in plan.mountedInstallerVolumes {
            do {
                try detachVolumeHandler(volumeURL)
            } catch {
                failures.append("\(volumeURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            throw InstallerCleanupError.cleanupFailed(failures.joined(separator: "\n"))
        }
    }

    private func mountedInstallerVolumes() -> [URL] {
        mountedVolumeProvider()
            .filter { url in
                let name = url.lastPathComponent
                guard name == "MacDog" || name.hasPrefix("MacDog ") else { return false }
                let appURL = url.appendingPathComponent("MacDog.app", isDirectory: true)
                let applicationsURL = url.appendingPathComponent("Applications")
                return fileManager.fileExists(atPath: appURL.path)
                    && fileManager.fileExists(atPath: applicationsURL.path)
            }
            .sorted { $0.path < $1.path }
    }

    private func downloadedInstallerFiles() -> [URL] {
        let searchDirectories = [
            homeDirectory.appendingPathComponent("Downloads", isDirectory: true),
            homeDirectory.appendingPathComponent("Desktop", isDirectory: true)
        ]
        let allowedExtensions = Set(["dmg", "sha256", "md"])

        return searchDirectories.flatMap { directory -> [URL] in
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else {
                return []
            }

            return files.filter { fileURL in
                let name = fileURL.lastPathComponent
                guard name.hasPrefix("MacDog-") else { return false }
                guard allowedExtensions.contains(fileURL.pathExtension.lowercased()) else { return false }
                return name.contains(".dmg")
                    || name.contains("release-notes")
                    || name.hasSuffix(".sha256")
            }
        }
        .sorted { $0.path < $1.path }
    }

    private static func detachVolume(at volumeURL: URL) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", volumeURL.path]
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let detail = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw InstallerCleanupError.detachFailed(detail ?? "hdiutil detach failed")
        }
    }
}

enum InstallerCleanupError: LocalizedError, Equatable {
    case detachFailed(String)
    case cleanupFailed(String)

    var errorDescription: String? {
        switch self {
        case .detachFailed(let detail):
            "설치 디스크를 꺼낼 수 없습니다: \(detail)"
        case .cleanupFailed(let detail):
            "일부 설치 파일을 정리하지 못했습니다.\n\(detail)"
        }
    }
}
