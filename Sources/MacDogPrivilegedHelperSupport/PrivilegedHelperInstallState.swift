import Foundation

public struct PrivilegedHelperInstallSnapshot: Equatable, Sendable {
    public static let missing = PrivilegedHelperInstallSnapshot(
        helperToolExists: false,
        launchDaemonExists: false
    )

    public let helperToolExists: Bool
    public let launchDaemonExists: Bool
    public let plan: PrivilegedHelperInstallPlan

    public init(
        helperToolExists: Bool,
        launchDaemonExists: Bool,
        plan: PrivilegedHelperInstallPlan = .current
    ) {
        self.helperToolExists = helperToolExists
        self.launchDaemonExists = launchDaemonExists
        self.plan = plan
    }

    public var status: PrivilegedHelperInstallStatus {
        switch (helperToolExists, launchDaemonExists) {
        case (false, false):
            .missing
        case (true, true):
            .installed
        default:
            .partial
        }
    }

    public var summary: String {
        switch status {
        case .missing:
            "권한 도우미 미설치"
        case .partial:
            "권한 도우미 일부만 설치됨"
        case .installed:
            "권한 도우미 설치됨"
        }
    }

    public var detailSummary: String {
        switch status {
        case .missing:
            "설정 변경 시 관리자 승인이 필요합니다."
        case .partial:
            "설치 파일 일부가 없어 복구가 필요합니다."
        case .installed:
            "설정 변경 시 반복 승인을 줄일 수 있습니다."
        }
    }

    public var guidanceTitle: String {
        switch status {
        case .missing:
            "권한 도우미 설치 필요"
        case .partial:
            "권한 도우미 복구 필요"
        case .installed:
            "권한 도우미 준비됨"
        }
    }

    public var guidanceDetail: String {
        switch status {
        case .missing:
            "덮개 닫힘 보호에서 반복 비밀번호를 피하려면 release DMG의 Install Privileged Helper.command를 실행하세요."
        case .partial:
            "도우미 실행 파일과 LaunchDaemon 중 일부만 있어 제거 후 다시 설치해야 합니다."
        case .installed:
            "덮개 닫힘 보호 변경은 권한 도우미 XPC 경로를 우선 사용합니다."
        }
    }

    public var requiresUserAction: Bool {
        status != .installed
    }
}

public enum PrivilegedHelperInstallStatus: String, Codable, Equatable, Sendable {
    case missing
    case partial
    case installed
}

public protocol PrivilegedHelperFileChecking {
    func fileExists(atPath path: String) -> Bool
}

public struct FileManagerPrivilegedHelperFileChecker: PrivilegedHelperFileChecking, Sendable {
    public init() {}

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

public struct PrivilegedHelperInstallStateReader<Checker: PrivilegedHelperFileChecking>: Sendable where Checker: Sendable {
    public let plan: PrivilegedHelperInstallPlan
    public let fileChecker: Checker

    public init(
        plan: PrivilegedHelperInstallPlan = .current,
        fileChecker: Checker
    ) {
        self.plan = plan
        self.fileChecker = fileChecker
    }

    public func snapshot() -> PrivilegedHelperInstallSnapshot {
        PrivilegedHelperInstallSnapshot(
            helperToolExists: fileChecker.fileExists(atPath: plan.helperToolDestination),
            launchDaemonExists: fileChecker.fileExists(atPath: plan.launchDaemonDestination),
            plan: plan
        )
    }
}
