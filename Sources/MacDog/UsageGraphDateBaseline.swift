import Foundation

enum UsageGraphDateBaseline: String, CaseIterable, Identifiable, Equatable, Sendable {
    case calendarMidnight
    case resetWindow

    static let defaultBaseline = UsageGraphDateBaseline.calendarMidnight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calendarMidnight:
            return "자정"
        case .resetWindow:
            return "리셋 시각"
        }
    }

    static func preferred(defaults: UserDefaults = .standard) -> UsageGraphDateBaseline {
        UsageGraphDateBaseline(rawValue: defaults.string(forKey: RunnerPreferences.usageGraphDateBaselineKey) ?? "")
            ?? defaultBaseline
    }

    static func boundaryTimestamps(
        resetStartAt: Int,
        resetsAt: Int,
        baseline: UsageGraphDateBaseline,
        calendar: Calendar
    ) -> [Int] {
        let start = min(resetStartAt, resetsAt)
        let end = max(resetStartAt, resetsAt)
        guard end > start else { return [start] }

        switch baseline {
        case .resetWindow:
            let duration = end - start
            let daySeconds = 86_400
            let dayCount = max(1, Int(ceil(Double(duration) / Double(daySeconds))))
            return (0...dayCount).map { min(start + $0 * daySeconds, end) }
        case .calendarMidnight:
            var times = [start]
            let startDate = Date(timeIntervalSince1970: TimeInterval(start))
            guard let startOfDay = calendar.dateInterval(of: .day, for: startDate)?.start,
                  let firstMidnight = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            else {
                return [start, end]
            }

            var cursor = firstMidnight
            let endDate = Date(timeIntervalSince1970: TimeInterval(end))
            while cursor < endDate {
                let timestamp = Int(cursor.timeIntervalSince1970)
                if timestamp > start && timestamp < end {
                    times.append(timestamp)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            times.append(end)
            return times
        }
    }

    static func gridPositions(
        resetStartAt: Int,
        resetsAt: Int,
        baseline: UsageGraphDateBaseline,
        calendar: Calendar
    ) -> [Double] {
        let start = min(resetStartAt, resetsAt)
        let duration = max(resetsAt - resetStartAt, 1)
        return boundaryTimestamps(
            resetStartAt: resetStartAt,
            resetsAt: resetsAt,
            baseline: baseline,
            calendar: calendar
        ).map { timestamp in
            min(max(Double(timestamp - start) / Double(duration), 0), 1)
        }
    }

    static func columnIndex(recordedAt: Int, boundaries: [Int]) -> Int {
        guard boundaries.count >= 2 else { return 0 }
        let lastIndex = boundaries.count - 2
        for index in 0...lastIndex {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            if index == lastIndex {
                if recordedAt >= start && recordedAt <= end {
                    return index
                }
            } else if recordedAt >= start && recordedAt < end {
                return index
            }
        }
        if recordedAt < boundaries[0] {
            return 0
        }
        return lastIndex
    }
}
