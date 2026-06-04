import SwiftUI

enum MacDogPopoverModule: String, CaseIterable, Identifiable {
    case codex
    case mac
    case sleep
    case battery
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            "Codex 사용량"
        case .mac:
            "활성 자원"
        case .sleep:
            "잠들지 않기"
        case .battery:
            "배터리"
        case .settings:
            "설정"
        }
    }

    var tabLabel: String {
        switch self {
        case .codex:
            "Codex"
        case .mac:
            "Mac"
        case .sleep:
            "잠들지\n않기"
        case .battery:
            "배터리"
        case .settings:
            "설정"
        }
    }

    var systemImage: String {
        MacDogCharacterProfile.codexPup.popoverTabs.artwork(for: self).systemImage
    }

    var artworkName: String {
        MacDogCharacterProfile.codexPup.popoverTabs.artwork(for: self).resourceName
    }

    var usesScrollableContent: Bool {
        switch self {
        case .codex, .mac, .sleep, .battery, .settings:
            false
        }
    }
}

enum MacDogPopoverLayout {
    static let outerSize = CGSize(width: 370, height: 408)
    static let outerPadding: CGFloat = 10
    static let contentSurfaceSize = CGSize(width: 278, height: 388)
    static let contentPadding: CGFloat = 12
    static let contentStackSpacing: CGFloat = 8
    static let headerHeight: CGFloat = 34
    static let dividerHeight: CGFloat = 1
    static let shellCornerRadius: CGFloat = 12
    static let shellBackgroundColor = Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96)

    static var nonScrollableContentHeight: CGFloat {
        contentSurfaceSize.height
            - (contentPadding * 2)
            - headerHeight
            - dividerHeight
            - (contentStackSpacing * 2)
    }
}

enum CodexUsagePanelLayout {
    static let weeklyGraphHeight: CGFloat = 74
    static let weeklyGraphYAxisWidth: CGFloat = 28
    static let weeklyGraphAxisSpacing: CGFloat = 5
    static let weeklyGraphTimelineHeight: CGFloat = 13

    static var weeklyGraphPlotStartX: CGFloat {
        weeklyGraphYAxisWidth + weeklyGraphAxisSpacing
    }
}

enum MacResourcesPanelLayout {
    static let verticalSpacing: CGFloat = 8
    static let sparklineHeight: CGFloat = 30
    static let trendBlockHeight: CGFloat = 68
    static let storageBlockHeight: CGFloat = 54
    static let networkBlockHeight: CGFloat = 56

    static var estimatedContentHeight: CGFloat {
        (trendBlockHeight * 2)
            + storageBlockHeight
            + networkBlockHeight
            + (MacDogPopoverLayout.dividerHeight * 3)
            + (verticalSpacing * 6)
    }
}
