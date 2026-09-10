import Foundation

struct UsageProviderMask: OptionSet, Equatable, Sendable {
    let rawValue: Int

    static let codex = UsageProviderMask(rawValue: 1 << 0)
    static let grok = UsageProviderMask(rawValue: 1 << 1)
    static let visible: UsageProviderMask = [.codex, .grok]
    static let claude = UsageProviderMask()

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

    var includesCodex: Bool { enabled.contains(.codex) }
    var includesGrok: Bool { enabled.contains(.grok) }

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
        let requestedMain: UsageProviderMode? = {
            switch main {
            case .codex, .grok:
                main
            case .claude, .none:
                nil
            }
        }()

        let enabled: UsageProviderMask = {
            guard let enabledRaw else {
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
