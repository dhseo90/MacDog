import SwiftUI

struct MacResourcesPanel: View {
    let snapshot: SystemMetricsSnapshot
    let history: SystemMetricsHistory

    var body: some View {
        VStack(alignment: .leading, spacing: MacResourcesPanelLayout.verticalSpacing) {
            ResourceTrendBlock(
                title: "CPU",
                systemImage: "cpu",
                value: snapshot.cpuSummary,
                details: [snapshot.cpuDetailSummary],
                values: trendValues(history.cpuLoadPercents, current: snapshot.cpuLoadPercent),
                tint: .blue
            )
            Divider()
            ResourceTrendBlock(
                title: "메모리",
                systemImage: "memorychip",
                value: snapshot.memorySummary,
                details: [snapshot.memoryDetailSummary],
                values: trendValues(history.memoryUsedPercents, current: snapshot.memoryUsedPercent),
                tint: .green
            )
            Divider()
            CompactResourceMetricBlock(
                title: "저장 용량",
                systemImage: "internaldrive",
                value: snapshot.diskSummary,
                details: [
                    snapshot.diskDetailSummary,
                    "홈 볼륨 기준"
                ],
                progress: snapshot.diskUsedPercent.map { Self.progress($0) }
            )
            Divider()
            CompactResourceMetricBlock(
                title: "네트워크",
                systemImage: "network",
                value: snapshot.primaryNetworkInterfaceName ?? "활성 인터페이스 \(snapshot.activeInterfaceCount)",
                details: [
                    snapshot.localNetworkSummary,
                    snapshot.networkRateSummary,
                    snapshot.networkSummary
                ],
                progress: nil
            )
        }
    }

    private static func progress(_ percent: Double) -> Double {
        min(max(percent / 100, 0), 1)
    }

    private func trendValues(_ values: [Double], current: Double?) -> [Double] {
        if values.isEmpty, let current {
            return [current]
        }
        return values
    }
}

private struct ResourceTrendBlock: View {
    let title: String
    let systemImage: String
    let value: String
    let details: [String]
    let values: [Double]
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                SparklineView(values: values, tint: tint)
                    .frame(height: MacResourcesPanelLayout.sparklineHeight)
                    .padding(.top, 2)
            }
        }
    }
}

private struct CompactResourceMetricBlock: View {
    let title: String
    let systemImage: String
    let value: String
    let details: [String]
    let progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if let progress {
                    ProgressView(value: progress)
                        .controlSize(.mini)
                        .tint(.accentColor)
                        .padding(.top, 1)
                }
            }
        }
    }
}

private struct SparklineView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.045))

                Path { path in
                    let centerY = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                }
                .stroke(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))

                Path { path in
                    addLine(to: &path, in: geometry.size)
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private func addLine(to path: inout Path, in size: CGSize) {
        let clampedValues = values.map { min(max($0, 0), 100) }
        guard let first = clampedValues.first else { return }
        let scale = SparklineScale(values: clampedValues)

        if clampedValues.count == 1 {
            let y = yPosition(for: first, height: size.height, scale: scale)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            return
        }

        let stepX = size.width / CGFloat(clampedValues.count - 1)
        for (index, value) in clampedValues.enumerated() {
            let point = CGPoint(
                x: CGFloat(index) * stepX,
                y: yPosition(for: value, height: size.height, scale: scale)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
    }

    private func yPosition(for value: Double, height: CGFloat, scale: SparklineScale) -> CGFloat {
        let normalized = CGFloat(scale.normalized(value))
        return height - (normalized * height)
    }
}

struct SparklineScale: Equatable {
    static let lowerBound: Double = 0
    static let upperBound: Double = 100

    init(values: [Double]) {
        _ = values
    }

    func normalized(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0), 100)
        let span = Self.upperBound - Self.lowerBound
        guard span > 0 else { return 0.5 }
        return min(max((clampedValue - Self.lowerBound) / span, 0), 1)
    }
}
