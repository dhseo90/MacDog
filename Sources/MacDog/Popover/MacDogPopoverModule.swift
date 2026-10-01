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
        case .codex, .mac, .sleep, .battery:
            false
        case .settings:
            true
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
    static let sectionSpacing: CGFloat = 3
    static let weeklyGraphHeight: CGFloat = 56
    static let weeklyOnlyGraphHeight: CGFloat = 89
    /// Plot height when both the reset-credit row and the remaining-credit row are visible.
    static let weeklyGraphHeightWithRemainingCredit: CGFloat = 36
    static let weeklyOnlyGraphHeightWithRemainingCredit: CGFloat = 51
    static let weeklyGraphYAxisWidth: CGFloat = 28
    static let weeklyGraphAxisSpacing: CGFloat = 5
    static let weeklyGraphTimelineHeight: CGFloat = 10
    /// Gap under the graph card, before the first credit row.
    static let detailGraphSpacing: CGFloat = 8
    /// Gap between 초기화권 and 잔여 크레딧.
    static let detailCardSpacing: CGFloat = 4
    /// Small gap above the data-status line, which sits on the column bottom.
    static let detailStatusSpacing: CGFloat = 12

    static func weeklyGraphHeight(
        fiveHourIsAvailable: Bool,
        showsResetCredit: Bool = true,
        showsRemainingCredit: Bool = false
    ) -> CGFloat {
        if fiveHourIsAvailable {
            switch (showsResetCredit, showsRemainingCredit) {
            case (true, true):
                return weeklyGraphHeightWithRemainingCredit
            case (false, false):
                return 93
            default:
                return weeklyGraphHeight
            }
        }
        switch (showsResetCredit, showsRemainingCredit) {
        case (true, true):
            return weeklyOnlyGraphHeightWithRemainingCredit
        case (false, false):
            return 127
        default:
            return weeklyOnlyGraphHeight
        }
    }

    static var weeklyGraphPlotStartX: CGFloat {
        weeklyGraphYAxisWidth + weeklyGraphAxisSpacing
    }
}

enum MacResourcesPanelLayout {
    static let verticalSpacing: CGFloat = 5
    static let sparklineHeight: CGFloat = 22
    static let summaryBlockHeight: CGFloat = 46
    static let trendBlockHeight: CGFloat = 58
    static let storageBlockHeight: CGFloat = 48
    static let networkBlockHeight: CGFloat = 50

    static var estimatedContentHeight: CGFloat {
        summaryBlockHeight
            + (trendBlockHeight * 2)
            + storageBlockHeight
            + networkBlockHeight
            + (MacDogPopoverLayout.dividerHeight * 4)
            + (verticalSpacing * 7)
    }
}
