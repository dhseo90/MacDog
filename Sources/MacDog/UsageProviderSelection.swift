import Foundation

struct UsageProviderMask: OptionSet, Equatable, Sendable {
    let rawValue: Int

    static let codex = UsageProviderMask(rawValue: 1 << 0)
    static let grok = UsageProviderMask(rawValue: 1 << 1)
    static let claude = UsageProviderMask(rawValue: 1 << 2)
    static let visible: UsageProviderMask = [.codex, .grok, .claude]

    var visibleMask: UsageProviderMask {
        intersection(.visible)
    }
}

struct UsageProviderSelection: Equatable, Sendable {
    let enabled: UsageProviderMask
    let main: UsageProviderMode
    let detailGraphVisible: Bool

    static let `default` = UsageProviderSelection(
        enabled: .codex,
        main: .codex,
        detailGraphVisible: true
    )

    static func exclusive(for mode: UsageProviderMode) -> UsageProviderSelection {
        normalized(
            enabledRaw: mask(for: mode).rawValue,
            main: mode,
            detailGraphVisible: true
        )
    }

    var includesCodex: Bool { includes(.codex) }
    var includesGrok: Bool { includes(.grok) }
    var includesClaude: Bool { includes(.claude) }
    var enabledModes: [UsageProviderMode] {
        UsageProviderMode.allCases.filter(includes)
    }
    var showsMainPicker: Bool { enabledModes.count > 1 }

    func includes(_ mode: UsageProviderMode) -> Bool {
        let bit = Self.mask(for: mode)
        return !bit.isEmpty && enabled.contains(bit)
    }

    func isOnlyEnabled(_ mode: UsageProviderMode) -> Bool {
        let bit = Self.mask(for: mode)
        return !bit.isEmpty && enabled.visibleMask == bit
    }

    static func mask(for mode: UsageProviderMode) -> UsageProviderMask {
        switch mode {
        case .codex:
            .codex
        case .grok:
            .grok
        case .claude:
            .claude
        }
    }

    static func normalized(
        enabledRaw: Int?,
        main: UsageProviderMode?,
        detailGraphVisible: Bool?
    ) -> UsageProviderSelection {
        let graphVisible = detailGraphVisible ?? true
        let requestedMain: UsageProviderMode? = main

        let enabled: UsageProviderMask = {
            guard let enabledRaw else {
                if requestedMain == .claude || requestedMain == nil {
                    return .codex
                }
                return mask(for: requestedMain ?? .codex)
            }
            let visible = UsageProviderMask(rawValue: enabledRaw).visibleMask
            return visible.isEmpty ? .codex : visible
        }()

        let resolvedMain: UsageProviderMode = {
            if let requestedMain, enabled.contains(mask(for: requestedMain)) {
                return requestedMain
            }
            if enabled.contains(.codex) {
                return .codex
            }
            if enabled.contains(.grok) {
                return .grok
            }
            if enabled.contains(.claude) {
                return .claude
            }
            return .codex
        }()

        return UsageProviderSelection(
            enabled: enabled.isEmpty ? .codex : enabled,
            main: resolvedMain,
            detailGraphVisible: graphVisible
        )
    }

    func enabling(_ mode: UsageProviderMode) -> UsageProviderSelection {
        let bit = Self.mask(for: mode)
        guard !bit.isEmpty else { return self }
        return Self.normalized(
            enabledRaw: enabled.union(bit).rawValue,
            main: main,
            detailGraphVisible: detailGraphVisible
        )
    }

    func disabling(_ mode: UsageProviderMode) -> UsageProviderSelection {
        let bit = Self.mask(for: mode)
        guard !bit.isEmpty else { return self }
        let next = enabled.subtracting(bit).visibleMask
        guard !next.isEmpty else { return self }
        return Self.normalized(
            enabledRaw: next.rawValue,
            main: main,
            detailGraphVisible: detailGraphVisible
        )
    }

    func settingMain(_ mode: UsageProviderMode) -> UsageProviderSelection {
        let bit = Self.mask(for: mode)
        guard !bit.isEmpty else { return self }
        return Self.normalized(
            enabledRaw: enabled.union(bit).rawValue,
            main: mode,
            detailGraphVisible: detailGraphVisible
        )
    }

    func settingDetailGraphVisible(_ isVisible: Bool) -> UsageProviderSelection {
        UsageProviderSelection(
            enabled: enabled,
            main: main,
            detailGraphVisible: isVisible
        )
    }
}
