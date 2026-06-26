import AppKit
import CodexUsageCore
import SwiftUI

struct WeeklyRemainingHistoryBlock: View {
    let history: CodexUsageWeeklyHistory
    let resetWindowHistory: CodexUsageResetWindowHistory
    let weeklyWindow: UsageWindowReport?
    let currentReport: CodexUsageReport?
    let currentTimestamp: Int?

    @State private var selectedMode: CodexUsageHistoryGraphMode = .current
    @State private var selectedPastWindowID: String?

    private var comparisonModel: CodexUsageHistoryComparisonModel? {
        CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: resetWindowHistory,
            weeklyWindow: weeklyWindow,
            currentReport: currentReport,
            currentTimestamp: currentTimestamp
        )
    }

    var body: some View {
        if let comparisonModel {
            let mode = effectiveMode(for: comparisonModel)
            let selectedSeries = selectedOverlaySeries(in: comparisonModel)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("주간 잔여량")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(summaryText(mode: mode, model: comparisonModel, selectedSeries: selectedSeries))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    graphActionButtons(mode: mode, model: comparisonModel, selectedSeries: selectedSeries)
                }

                if comparisonModel.availableModes.count > 1 {
                    HStack(spacing: 6) {
                        Picker("", selection: $selectedMode) {
                            ForEach(comparisonModel.availableModes) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.mini)
                        .labelsHidden()

                        if mode != .current, !comparisonModel.pastWindows.isEmpty {
                            Picker("", selection: selectedPastWindowIDBinding(for: comparisonModel)) {
                                ForEach(comparisonModel.pastWindows) { window in
                                    Text(windowLabel(for: window))
                                        .tag(Optional(window.id))
                                }
                            }
                            .labelsHidden()
                            .controlSize(.mini)
                            .frame(width: 94)
                        }
                    }
                }

                graph(mode: mode, model: comparisonModel, selectedSeries: selectedSeries)
                    .frame(height: CodexUsagePanelLayout.weeklyGraphHeight)

                WeeklyRemainingTimelineLabels(
                    startLabel: timelineStartLabel(mode: mode, model: comparisonModel, selectedSeries: selectedSeries),
                    endLabel: timelineEndLabel(mode: mode, model: comparisonModel, selectedSeries: selectedSeries)
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("주간 잔여량 그래프")
            .accessibilityValue(accessibilityValue(mode: mode, model: comparisonModel, selectedSeries: selectedSeries))
        }
    }

    @ViewBuilder
    private func graph(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> some View {
        CodexUsageGraphDisplay(
            mode: mode,
            currentChart: model.currentChart,
            selectedSeries: selectedSeries
        )
    }

    private func graphActionButtons(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> some View {
        HStack(spacing: 4) {
            Button {
                copyVisibleGraph(mode: mode, model: model, selectedSeries: selectedSeries)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("PNG 복사")

            Button {
                exportVisibleGraph(mode: mode, model: model, selectedSeries: selectedSeries)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("PNG 내보내기")
        }
        .foregroundStyle(.secondary)
    }

    private func effectiveMode(for model: CodexUsageHistoryComparisonModel) -> CodexUsageHistoryGraphMode {
        model.availableModes.contains(selectedMode) ? selectedMode : .current
    }

    private func selectedOverlaySeries(
        in model: CodexUsageHistoryComparisonModel
    ) -> CodexUsageResetWindowOverlaySeries? {
        guard let selectedID = selectedPastWindowID,
              let selectedWindow = model.pastWindows.first(where: { $0.id == selectedID })
        else {
            return model.overlaySeries
        }
        return CodexUsageResetWindowOverlayBuilder().model(
            history: model.resetWindowHistory,
            selectedKey: selectedWindow.key,
            excludingCurrentResetsAt: weeklyWindow?.resetsAt
        ).selectedSeries
    }

    private func selectedPastWindowIDBinding(
        for model: CodexUsageHistoryComparisonModel
    ) -> Binding<String?> {
        Binding(
            get: {
                selectedPastWindowID ?? model.pastWindows.first?.id
            },
            set: { newValue in
                selectedPastWindowID = newValue
            }
        )
    }

    private func summaryText(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> String {
        switch mode {
        case .current:
            return model.currentChart.summaryText
        case .past:
            guard let selectedSeries else { return "지난 기록 없음" }
            return "지난 window 최종 \(UsageMonitorState.percent(selectedSeries.finalUsageMarker.usedPercent))% 사용"
        case .overlay:
            guard selectedSeries != nil else { return "비교할 지난 기록 없음" }
            return "현재 pace와 지난 window 비교"
        }
    }

    private func timelineStartLabel(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> String {
        switch mode {
        case .current:
            return model.currentChart.timelineStartDisplayLabel
        case .past, .overlay:
            return CodexUsageHistoryTimelineLabel.startLabel(for: selectedSeries)
        }
    }

    private func timelineEndLabel(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> String {
        switch mode {
        case .current:
            return model.currentChart.resetEndLabel
        case .past, .overlay:
            return CodexUsageHistoryTimelineLabel.endLabel(for: selectedSeries)
        }
    }

    private func accessibilityValue(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> String {
        switch mode {
        case .current:
            return model.currentChart.accessibilityValue
        case .past, .overlay:
            guard let selectedSeries else { return mode == .past ? "지난 기록 없음" : "비교할 지난 기록 없음" }
            return "지난 window 최종 사용 \(UsageMonitorState.percent(selectedSeries.finalUsageMarker.usedPercent))%"
        }
    }

    private func windowLabel(for window: CodexUsageResetWindowOverlayWindow) -> String {
        CodexUsageHistoryTimelineLabel.windowLabel(for: window)
    }

    private func copyVisibleGraph(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) {
        guard let data = visibleGraphPNGData(mode: mode, model: model, selectedSeries: selectedSeries) else {
            return
        }
        CodexUsageGraphImageExporter.copyPNGData(data)
    }

    private func exportVisibleGraph(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) {
        guard let data = visibleGraphPNGData(mode: mode, model: model, selectedSeries: selectedSeries) else {
            return
        }
        CodexUsageGraphImageExporter.exportPNGData(
            data,
            suggestedFileName: "macdog-codex-usage-\(mode.rawValue).png"
        )
    }

    private func visibleGraphPNGData(
        mode: CodexUsageHistoryGraphMode,
        model: CodexUsageHistoryComparisonModel,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) -> Data? {
        CodexUsageGraphImageExporter.pngData(
            for: CodexUsageGraphSnapshotView(
                mode: mode,
                currentChart: model.currentChart,
                selectedSeries: selectedSeries
            ),
            size: CodexUsageGraphImageExporter.defaultImageSize,
            scale: 2
        )
    }
}

private struct CodexUsageGraphDisplay: View {
    let mode: CodexUsageHistoryGraphMode
    let currentChart: WeeklyRemainingHistoryChart
    let selectedSeries: CodexUsageResetWindowOverlaySeries?

    var body: some View {
        switch mode {
        case .current:
            WeeklyRemainingHistoryGraph(chart: currentChart)
        case .past:
            if let selectedSeries {
                ResetWindowOverlayGraph(currentChart: nil, series: selectedSeries)
            } else {
                ResetWindowHistoryUnavailableGraph(message: "지난 기록 없음")
            }
        case .overlay:
            if let selectedSeries {
                ResetWindowOverlayGraph(currentChart: currentChart, series: selectedSeries)
            } else {
                ResetWindowHistoryUnavailableGraph(message: "비교할 지난 기록 없음")
            }
        }
    }
}

private struct CodexUsageGraphSnapshotView: View {
    let mode: CodexUsageHistoryGraphMode
    let currentChart: WeeklyRemainingHistoryChart
    let selectedSeries: CodexUsageResetWindowOverlaySeries?

    var body: some View {
        VStack(spacing: 8) {
            CodexUsageGraphDisplay(
                mode: mode,
                currentChart: currentChart,
                selectedSeries: selectedSeries
            )
            WeeklyRemainingTimelineLabels(
                startLabel: snapshotStartLabel,
                endLabel: snapshotEndLabel
            )
        }
        .padding(12)
    }

    private var snapshotStartLabel: String {
        switch mode {
        case .current:
            return currentChart.timelineStartDisplayLabel
        case .past, .overlay:
            return CodexUsageHistoryTimelineLabel.startLabel(for: selectedSeries)
        }
    }

    private var snapshotEndLabel: String {
        switch mode {
        case .current:
            return currentChart.resetEndLabel
        case .past, .overlay:
            return CodexUsageHistoryTimelineLabel.endLabel(for: selectedSeries)
        }
    }
}

enum WeeklyRemainingTimelineLabelLayout {
    static let labelSpacing: CGFloat = 6
    static let endLabelWidth: CGFloat = 48

    static var leadingInset: CGFloat {
        CodexUsagePanelLayout.weeklyGraphPlotStartX
    }

    static func startLabelWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth - leadingInset - labelSpacing - endLabelWidth)
    }
}

private struct WeeklyRemainingTimelineLabels: View {
    let startLabel: String
    let endLabel: String

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: WeeklyRemainingTimelineLabelLayout.labelSpacing) {
                Text(startLabel)
                    .frame(
                        width: WeeklyRemainingTimelineLabelLayout.startLabelWidth(totalWidth: geometry.size.width),
                        alignment: .leading
                    )
                    .truncationMode(.tail)

                Text(endLabel)
                    .frame(width: WeeklyRemainingTimelineLabelLayout.endLabelWidth, alignment: .trailing)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.leading, WeeklyRemainingTimelineLabelLayout.leadingInset)
            .frame(
                width: geometry.size.width,
                height: CodexUsagePanelLayout.weeklyGraphTimelineHeight,
                alignment: .leading
            )
        }
        .frame(height: CodexUsagePanelLayout.weeklyGraphTimelineHeight)
    }
}

private struct WeeklyRemainingHistoryGraph: View {
    let chart: WeeklyRemainingHistoryChart

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: CodexUsagePanelLayout.weeklyGraphAxisSpacing) {
                WeeklyRemainingHistoryYAxisLabels()
                    .frame(width: CodexUsagePanelLayout.weeklyGraphYAxisWidth, height: geometry.size.height)

                WeeklyRemainingHistoryPlot(chart: chart, tint: tint)
                    .frame(
                        width: max(
                            0,
                            geometry.size.width -
                                CodexUsagePanelLayout.weeklyGraphPlotStartX
                        ),
                        height: geometry.size.height
                    )
            }
        }
    }

    private var tint: Color {
        switch chart.latestActualPoint?.remainingPercent ?? 100 {
        case ..<10:
            .red
        case 10..<30:
            .orange
        case 30..<60:
            .yellow
        default:
            .green
        }
    }
}

private struct WeeklyRemainingHistoryYAxisLabels: View {
    var body: some View {
        VStack(alignment: .trailing) {
            Text("100%")
            Spacer()
            Text("50%")
            Spacer()
            Text("0%")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary.opacity(0.76))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct ResetWindowHistoryUnavailableGraph: View {
    let message: String

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: CodexUsagePanelLayout.weeklyGraphAxisSpacing) {
                WeeklyRemainingHistoryYAxisLabels()
                    .frame(width: CodexUsagePanelLayout.weeklyGraphYAxisWidth, height: geometry.size.height)

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    Text(message)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 8)
                }
                .frame(
                    width: max(
                        0,
                        geometry.size.width -
                            CodexUsagePanelLayout.weeklyGraphPlotStartX
                    ),
                    height: geometry.size.height
                )
            }
        }
    }
}

private struct WeeklyRemainingHistoryPlot: View {
    let chart: WeeklyRemainingHistoryChart
    let tint: Color

    @State private var hoveredMarkerID: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.045))

                guideLines(in: geometry.size)
                    .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))

                chartLine(in: geometry.size)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .butt, lineJoin: .round))

                ForEach(chart.dayMarkers) { marker in
                    let markerPoint = point(for: marker.point, in: geometry.size)

                    ZStack {
                        Circle()
                            .fill(marker.id == hoveredMarkerID ? tint : Color.primary.opacity(0.42))
                            .frame(
                                width: marker.id == hoveredMarkerID ? 6 : 4,
                                height: marker.id == hoveredMarkerID ? 6 : 4
                            )
                    }
                    .frame(
                        width: WeeklyRemainingHistoryInteraction.markerHitDiameter,
                        height: WeeklyRemainingHistoryInteraction.markerHitDiameter
                    )
                    .contentShape(Rectangle())
                    .onHover { isHovering in
                        if isHovering {
                            hoveredMarkerID = marker.id
                        } else if hoveredMarkerID == marker.id {
                            hoveredMarkerID = nil
                        }
                    }
                    .onTapGesture {
                        hoveredMarkerID = marker.id
                    }
                        .position(markerPoint)
                }

                if let latest = chart.latestActualPoint {
                    let latestPoint = point(for: latest, in: geometry.size)

                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 11, height: 11)
                        .position(latestPoint)
                        .allowsHitTesting(false)

                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                        .position(latestPoint)
                        .allowsHitTesting(false)

                    if hoveredMarker?.point != latest {
                        Text("\(UsageMonitorState.percent(latest.remainingPercent))%")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .position(
                                WeeklyRemainingHistoryLabelPlacement.valueLabelPosition(
                                    for: latestPoint,
                                    in: geometry.size
                                )
                            )
                            .allowsHitTesting(false)
                    }
                }

                if let hoveredMarker {
                    let markerPoint = point(for: hoveredMarker.point, in: geometry.size)
                    let latestLabelPosition = latestLabelPositionToAvoid(for: hoveredMarker, in: geometry.size)

                    Text(hoveredMarker.hoverLabel)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .position(
                            WeeklyRemainingHistoryLabelPlacement.hoverLabelPosition(
                                for: markerPoint,
                                avoiding: latestLabelPosition,
                                in: geometry.size
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredMarkerID = nearestMarkerID(to: location, in: geometry.size)
                case .ended:
                    hoveredMarkerID = nil
                }
            }
        }
    }

    private var hoveredMarker: WeeklyRemainingHistoryDayMarker? {
        guard let hoveredMarkerID else { return nil }
        return chart.dayMarkers.first { $0.id == hoveredMarkerID }
    }

    private func guideLines(in size: CGSize) -> Path {
        Path { path in
            for fraction in [0.0, 0.5, 1.0] {
                let y = size.height * CGFloat(fraction)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            for fraction in chart.dayGridPositions {
                let x = size.width * CGFloat(fraction)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
    }

    private func chartLine(in size: CGSize) -> Path {
        Path { path in
            guard chart.points.count > 1 else { return }

            for (index, point) in chart.points.enumerated() {
                let cgPoint = self.point(for: point, in: size)
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
        }
    }

    private func point(for point: WeeklyRemainingHistoryPoint, in size: CGSize) -> CGPoint {
        WeeklyRemainingHistoryInteraction.point(for: point, in: size)
    }

    private func latestLabelPositionToAvoid(
        for hoveredMarker: WeeklyRemainingHistoryDayMarker,
        in size: CGSize
    ) -> CGPoint? {
        guard let latest = chart.latestActualPoint,
              hoveredMarker.point != latest
        else {
            return nil
        }

        return WeeklyRemainingHistoryLabelPlacement.valueLabelPosition(
            for: point(for: latest, in: size),
            in: size
        )
    }

    private func nearestMarkerID(to location: CGPoint, in size: CGSize) -> Int? {
        WeeklyRemainingHistoryInteraction.nearestMarkerID(
            to: location,
            markers: chart.dayMarkers,
            in: size
        )
    }
}

private struct ResetWindowOverlayGraph: View {
    let currentChart: WeeklyRemainingHistoryChart?
    let series: CodexUsageResetWindowOverlaySeries

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: CodexUsagePanelLayout.weeklyGraphAxisSpacing) {
                WeeklyRemainingHistoryYAxisLabels()
                    .frame(width: CodexUsagePanelLayout.weeklyGraphYAxisWidth, height: geometry.size.height)

                ResetWindowOverlayPlot(
                    currentChart: currentChart,
                    series: series
                )
                .frame(
                    width: max(
                        0,
                        geometry.size.width -
                            CodexUsagePanelLayout.weeklyGraphPlotStartX
                    ),
                    height: geometry.size.height
                )
            }
        }
    }
}

private struct ResetWindowOverlayPlot: View {
    let currentChart: WeeklyRemainingHistoryChart?
    let series: CodexUsageResetWindowOverlaySeries

    @State private var hoveredMarkerID: String?

    private var markers: [CodexUsageResetWindowOverlayMarker] {
        series.dayEndMarkers + [series.finalUsageMarker]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.045))

                guideLines(in: geometry.size)
                    .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))

                if let currentChart {
                    currentLine(chart: currentChart, in: geometry.size)
                        .stroke(.green, style: StrokeStyle(lineWidth: 1.4, lineCap: .butt, lineJoin: .round))
                        .opacity(0.72)
                }

                seriesLine(in: geometry.size)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 1.8, lineCap: .butt, lineJoin: .round))

                ForEach(markers) { marker in
                    let markerPoint = point(for: marker, in: geometry.size)
                    markerShape(for: marker, isHovered: hoveredMarkerID == marker.id)
                        .frame(
                            width: WeeklyRemainingHistoryInteraction.markerHitDiameter,
                            height: WeeklyRemainingHistoryInteraction.markerHitDiameter
                        )
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            if isHovering {
                                hoveredMarkerID = marker.id
                            } else if hoveredMarkerID == marker.id {
                                hoveredMarkerID = nil
                            }
                        }
                        .onTapGesture {
                            hoveredMarkerID = marker.id
                        }
                        .position(markerPoint)
                }

                if let hoveredMarker {
                    let markerPoint = point(for: hoveredMarker, in: geometry.size)
                    Text(CodexUsageHistoryMarkerLabel.hoverText(for: hoveredMarker))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .position(
                            WeeklyRemainingHistoryLabelPlacement.hoverLabelPosition(
                                for: markerPoint,
                                avoiding: nil,
                                in: geometry.size
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredMarkerID = nearestMarkerID(to: location, in: geometry.size)
                case .ended:
                    hoveredMarkerID = nil
                }
            }
        }
    }

    private var hoveredMarker: CodexUsageResetWindowOverlayMarker? {
        guard let hoveredMarkerID else { return nil }
        return markers.first { $0.id == hoveredMarkerID }
    }

    private func guideLines(in size: CGSize) -> Path {
        Path { path in
            for fraction in [0.0, 0.5, 1.0] {
                let y = size.height * CGFloat(fraction)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            for day in 0...7 {
                let x = size.width * CGFloat(Double(day) / 7.0)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
    }

    private func currentLine(chart: WeeklyRemainingHistoryChart, in size: CGSize) -> Path {
        Path { path in
            guard chart.points.count > 1 else { return }
            for (index, point) in chart.points.enumerated() {
                let cgPoint = WeeklyRemainingHistoryInteraction.point(for: point, in: size)
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
        }
    }

    private func seriesLine(in size: CGSize) -> Path {
        Path { path in
            guard series.linePoints.count > 1 else { return }
            for (index, marker) in series.linePoints.enumerated() {
                let cgPoint = point(for: marker, in: size)
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
        }
    }

    private func point(for marker: CodexUsageResetWindowOverlayMarker, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(marker.timelinePosition),
            y: size.height * CGFloat(1 - min(max(marker.remainingPercent / 100, 0), 1))
        )
    }

    @ViewBuilder
    private func markerShape(
        for marker: CodexUsageResetWindowOverlayMarker,
        isHovered: Bool
    ) -> some View {
        let size: CGFloat = isHovered ? 7 : 5
        if marker.kind == .finalUsage {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.orange)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(45))
        } else {
            Circle()
                .fill(isHovered ? .blue : Color.primary.opacity(0.46))
                .frame(width: size, height: size)
        }
    }

    private func nearestMarkerID(to location: CGPoint, in size: CGSize) -> String? {
        var nearestID: String?
        var nearestDistance: CGFloat = 24

        for marker in markers {
            let markerPoint = point(for: marker, in: size)
            let distance = hypot(markerPoint.x - location.x, markerPoint.y - location.y)
            if distance <= nearestDistance {
                nearestID = marker.id
                nearestDistance = distance
            }
        }

        return nearestID
    }
}

struct WeeklyRemainingHistoryLabelPlacement {
    static let valueLabelSize = CGSize(width: 30, height: 12)
    static let hoverLabelSize = CGSize(width: 74, height: 12)
    static let collisionPadding = CGSize(width: 4, height: 3)

    static func valueLabelPosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        let xOffset: CGFloat = point.x > size.width - 34 ? -24 : 24
        let yOffset: CGFloat
        if point.y < 14 {
            yOffset = 12
        } else if point.y > size.height - 14 {
            yOffset = -12
        } else {
            yOffset = -11
        }

        return CGPoint(
            x: min(max(point.x + xOffset, 18), size.width - 18),
            y: min(max(point.y + yOffset, 9), size.height - 9)
        )
    }

    static func hoverLabelPosition(
        for point: CGPoint,
        avoiding latestLabelPosition: CGPoint?,
        in size: CGSize
    ) -> CGPoint {
        let xOffset: CGFloat = point.x > size.width - 46 ? -35 : 35
        let yOffsets: [CGFloat] = point.y < 16 ? [13, -13, 25, -25] : [-13, 13, -25, 25]
        let xOffsets: [CGFloat] = [xOffset, -xOffset]

        let candidates = xOffsets.flatMap { xOffset in
            yOffsets.map { yOffset in
                clampedPosition(
                    CGPoint(x: point.x + xOffset, y: point.y + yOffset),
                    in: size,
                    horizontalMargin: 22,
                    verticalMargin: 9
                )
            }
        }

        guard let latestLabelPosition else {
            return candidates[0]
        }

        let latestRect = labelRect(center: latestLabelPosition, size: valueLabelSize)
            .insetBy(dx: -collisionPadding.width, dy: -collisionPadding.height)
        if let clearCandidate = candidates.first(where: {
            !labelRect(center: $0, size: hoverLabelSize).intersects(latestRect)
        }) {
            return clearCandidate
        }

        return candidates.max {
            distanceSquared(from: $0, to: latestLabelPosition) <
                distanceSquared(from: $1, to: latestLabelPosition)
        } ?? candidates[0]
    }

    static func labelRect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func clampedPosition(
        _ point: CGPoint,
        in size: CGSize,
        horizontalMargin: CGFloat,
        verticalMargin: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: min(max(point.x, horizontalMargin), size.width - horizontalMargin),
            y: min(max(point.y, verticalMargin), size.height - verticalMargin)
        )
    }

    private static func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}

struct WeeklyRemainingHistoryChart: Equatable {
    let points: [WeeklyRemainingHistoryPoint]
    let dayGridPositions: [Double]
    let dayMarkers: [WeeklyRemainingHistoryDayMarker]
    let actualSampleCount: Int
    let latestActualPoint: WeeklyRemainingHistoryPoint?
    let resetStartAt: Int?
    let resetsAt: Int?
    let resetStartLabel: String
    let resetEndLabel: String
    let recordingStartLabel: String?

    init(
        history: CodexUsageWeeklyHistory,
        weeklyWindow: UsageWindowReport?,
        currentSample: CodexUsageWeeklyHistorySample? = nil,
        calendar: Calendar = .current
    ) {
        guard let weeklyWindow,
              let resetsAt = weeklyWindow.resetsAt
        else {
            self.points = []
            self.dayGridPositions = []
            self.dayMarkers = []
            self.actualSampleCount = 0
            self.latestActualPoint = nil
            self.resetStartAt = nil
            self.resetsAt = nil
            self.resetStartLabel = "시작"
            self.resetEndLabel = "종료"
            self.recordingStartLabel = nil
            return
        }

        let durationMins = weeklyWindow.windowDurationMins ?? 10_080
        let durationSeconds = max(durationMins, 1) * 60
        let resetStartAt = resetsAt - durationSeconds
        let resetWindowToleranceSeconds = CodexUsageWeeklyHistorySample.resetWindowTimestampToleranceSeconds
        var samples = history.samples.filter {
            $0.matchesResetWindow(resetsAt: resetsAt, windowDurationMins: durationMins) &&
                $0.recordedAt >= resetStartAt &&
                $0.recordedAt <= resetsAt + resetWindowToleranceSeconds
        }

        if let currentSample,
           currentSample.matchesResetWindow(resetsAt: resetsAt, windowDurationMins: durationMins),
           currentSample.recordedAt >= resetStartAt,
           currentSample.recordedAt <= resetsAt + resetWindowToleranceSeconds,
           !samples.contains(where: { $0.recordedAt == currentSample.recordedAt }) {
            samples.append(currentSample)
        }

        samples.sort { $0.recordedAt < $1.recordedAt }

        let dayGridPositions = Self.dayGridPositions(durationSeconds: durationSeconds)
        var displayedRemainingPercent = 100.0
        let actualPoints = samples.map {
            displayedRemainingPercent = min(displayedRemainingPercent, $0.remainingPercent)
            return WeeklyRemainingHistoryPoint(
                recordedAt: $0.recordedAt,
                remainingPercent: displayedRemainingPercent,
                xPosition: Self.xPosition(
                    recordedAt: $0.recordedAt,
                    resetStartAt: resetStartAt,
                    durationSeconds: durationSeconds
                ),
                isResetAnchor: false
            )
        }
        let resetAnchor = WeeklyRemainingHistoryPoint(
            recordedAt: resetStartAt,
            remainingPercent: 100,
            xPosition: 0,
            isResetAnchor: true
        )
        let latestActualPoint = actualPoints.last
        let completedMarkers = Self.completedDayMarkers(
            from: actualPoints,
            resetAnchor: resetAnchor,
            resetStartAt: resetStartAt,
            durationSeconds: durationSeconds,
            currentSampleRecordedAt: currentSample?.recordedAt,
            calendar: calendar
        )

        self.points = Self.linePoints(
            resetAnchor: resetAnchor,
            completedMarkers: completedMarkers,
            actualPoints: actualPoints,
            currentSampleRecordedAt: currentSample?.recordedAt
        )
        self.dayGridPositions = dayGridPositions
        self.dayMarkers = Self.dayMarkers(
            from: actualPoints,
            completedMarkers: completedMarkers,
            resetStartAt: resetStartAt,
            durationSeconds: durationSeconds,
            currentSampleRecordedAt: currentSample?.recordedAt,
            calendar: calendar
        )
        self.actualSampleCount = actualPoints.count
        self.latestActualPoint = latestActualPoint
        self.resetStartAt = resetStartAt
        self.resetsAt = resetsAt
        self.resetStartLabel = Self.resetDayLabel(timestamp: resetStartAt, calendar: calendar)
        self.resetEndLabel = Self.resetDayLabel(timestamp: resetsAt, calendar: calendar)
        self.recordingStartLabel = actualPoints.first.map {
            "기록 시작 \(Self.resetDayTimeLabel(timestamp: $0.recordedAt, calendar: calendar))"
        }
    }

    var summaryText: String {
        guard let latestActualPoint else {
            return resetsAt == nil ? "초기화 시각 필요" : "샘플 대기"
        }
        return "\(UsageMonitorState.percent(latestActualPoint.remainingPercent))% 남음"
    }

    var timelineStartDisplayLabel: String {
        recordingStartLabel ?? resetStartLabel
    }

    var accessibilityValue: String {
        guard let latestActualPoint else {
            return summaryText
        }
        return "최근 주간 잔여량 \(UsageMonitorState.percent(latestActualPoint.remainingPercent))%, 샘플 \(actualSampleCount)개"
    }

    private static func xPosition(
        recordedAt: Int,
        resetStartAt: Int,
        durationSeconds: Int
    ) -> Double {
        let elapsed = Double(recordedAt - resetStartAt)
        return min(max(elapsed / Double(durationSeconds), 0), 1)
    }

    private static func dayGridPositions(durationSeconds: Int) -> [Double] {
        let daySeconds = 86_400
        let dayCount = max(1, Int(ceil(Double(durationSeconds) / Double(daySeconds))))

        return (0...dayCount).map {
            min(Double($0 * daySeconds) / Double(durationSeconds), 1)
        }
    }

    private static func dayMarkers(
        from actualPoints: [WeeklyRemainingHistoryPoint],
        completedMarkers: [WeeklyRemainingHistoryDayMarker],
        resetStartAt: Int,
        durationSeconds: Int,
        currentSampleRecordedAt: Int?,
        calendar: Calendar
    ) -> [WeeklyRemainingHistoryDayMarker] {
        let daySeconds = 86_400
        let dayCount = max(1, Int(ceil(Double(durationSeconds) / Double(daySeconds))))
        let maxDayIndex = max(0, dayCount - 1)
        let currentDayIndex = currentSampleRecordedAt.map {
            dayIndex(
                recordedAt: $0,
                resetStartAt: resetStartAt,
                durationSeconds: durationSeconds,
                daySeconds: daySeconds,
                maxDayIndex: maxDayIndex
            )
        }

        guard let currentDayIndex,
              let currentRecordedAt = currentSampleRecordedAt,
              let currentPoint = actualPoints.last(where: { $0.recordedAt == currentRecordedAt }) ?? actualPoints.last
        else {
            return measuredDayMarkers(
                from: actualPoints,
                resetStartAt: resetStartAt,
                durationSeconds: durationSeconds,
                daySeconds: daySeconds,
                calendar: calendar
            )
        }

        let currentDayLabel = resetDayLabel(timestamp: resetStartAt + currentDayIndex * daySeconds, calendar: calendar)
        let currentMarker = WeeklyRemainingHistoryDayMarker(
            id: currentDayIndex,
            point: currentPoint,
            hoverLabel: "\(currentDayLabel) · \(UsageMonitorState.percent(currentPoint.remainingPercent))%"
        )

        return completedMarkers + [currentMarker]
    }

    private static func measuredDayMarkers(
        from actualPoints: [WeeklyRemainingHistoryPoint],
        resetStartAt: Int,
        durationSeconds: Int,
        daySeconds: Int,
        calendar: Calendar
    ) -> [WeeklyRemainingHistoryDayMarker] {
        var latestByDay: [Int: WeeklyRemainingHistoryPoint] = [:]
        let maxDayIndex = max(0, Int(ceil(Double(durationSeconds) / Double(daySeconds))) - 1)

        for point in actualPoints.sorted(by: { $0.recordedAt < $1.recordedAt }) {
            let pointDayIndex = dayIndex(
                recordedAt: point.recordedAt,
                resetStartAt: resetStartAt,
                durationSeconds: durationSeconds,
                daySeconds: daySeconds,
                maxDayIndex: maxDayIndex
            )
            latestByDay[pointDayIndex] = point
        }

        return latestByDay.keys.sorted().compactMap { dayIndex in
            guard let point = latestByDay[dayIndex] else { return nil }
            let dayLabel = resetDayLabel(timestamp: resetStartAt + dayIndex * daySeconds, calendar: calendar)
            return WeeklyRemainingHistoryDayMarker(
                id: dayIndex,
                point: point,
                hoverLabel: "\(dayLabel) · \(UsageMonitorState.percent(point.remainingPercent))%"
            )
        }
    }

    private static func completedDayMarkers(
        from actualPoints: [WeeklyRemainingHistoryPoint],
        resetAnchor: WeeklyRemainingHistoryPoint,
        resetStartAt: Int,
        durationSeconds: Int,
        currentSampleRecordedAt: Int?,
        calendar: Calendar
    ) -> [WeeklyRemainingHistoryDayMarker] {
        guard let currentSampleRecordedAt else { return [] }

        let daySeconds = 86_400
        let dayCount = max(1, Int(ceil(Double(durationSeconds) / Double(daySeconds))))
        let maxDayIndex = max(0, dayCount - 1)
        let currentDayIndex = dayIndex(
            recordedAt: currentSampleRecordedAt,
            resetStartAt: resetStartAt,
            durationSeconds: durationSeconds,
            daySeconds: daySeconds,
            maxDayIndex: maxDayIndex
        )
        let maxCompletedDayIndex = min(currentDayIndex - 1, maxDayIndex)
        guard maxCompletedDayIndex >= 0 else { return [] }

        let sortedPoints = actualPoints.sorted { $0.recordedAt < $1.recordedAt }
        var latestPoint = resetAnchor
        var nextPointIndex = 0
        var markers: [WeeklyRemainingHistoryDayMarker] = []

        for dayIndex in 0...maxCompletedDayIndex {
            let slotStartAt = resetStartAt + dayIndex * daySeconds
            let slotEndAt = min(resetStartAt + (dayIndex + 1) * daySeconds, resetStartAt + durationSeconds)

            while nextPointIndex < sortedPoints.count,
                  sortedPoints[nextPointIndex].recordedAt <= slotEndAt {
                latestPoint = sortedPoints[nextPointIndex]
                nextPointIndex += 1
            }

            let markerPoint = WeeklyRemainingHistoryPoint(
                recordedAt: slotEndAt,
                remainingPercent: latestPoint.remainingPercent,
                xPosition: xPosition(
                    recordedAt: slotEndAt,
                    resetStartAt: resetStartAt,
                    durationSeconds: durationSeconds
                ),
                isResetAnchor: false
            )
            let dayLabel = resetDayLabel(timestamp: slotStartAt, calendar: calendar)
            markers.append(WeeklyRemainingHistoryDayMarker(
                id: dayIndex,
                point: markerPoint,
                hoverLabel: "\(dayLabel) 종료 · \(UsageMonitorState.percent(markerPoint.remainingPercent))%"
            ))
        }

        return markers
    }

    private static func linePoints(
        resetAnchor: WeeklyRemainingHistoryPoint,
        completedMarkers: [WeeklyRemainingHistoryDayMarker],
        actualPoints: [WeeklyRemainingHistoryPoint],
        currentSampleRecordedAt: Int?
    ) -> [WeeklyRemainingHistoryPoint] {
        let currentRecordedAt = currentSampleRecordedAt ?? actualPoints.last?.recordedAt
        let markerPoints = completedMarkers.map(\.point)
        let actualLinePoints = actualPoints.filter {
            guard let currentRecordedAt else { return true }
            return $0.recordedAt <= currentRecordedAt
        }
        let combined = [resetAnchor] + markerPoints + actualLinePoints
        let sorted = combined.sorted {
            if $0.recordedAt == $1.recordedAt {
                return !$0.isResetAnchor && $1.isResetAnchor
            }
            return $0.recordedAt < $1.recordedAt
        }

        return sorted.reduce(into: [WeeklyRemainingHistoryPoint]()) { result, point in
            if result.last?.recordedAt == point.recordedAt {
                result[result.count - 1] = point
            } else {
                result.append(point)
            }
        }
    }

    private static func dayIndex(
        recordedAt: Int,
        resetStartAt: Int,
        durationSeconds: Int,
        daySeconds: Int,
        maxDayIndex: Int
    ) -> Int {
        let elapsed = min(max(recordedAt - resetStartAt, 0), max(durationSeconds - 1, 0))
        return min(max(Int(Double(elapsed) / Double(daySeconds)), 0), maxDayIndex)
    }

    private static func resetDayLabel(timestamp: Int, calendar inputCalendar: Calendar) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let components = inputCalendar.dateComponents([.month, .day, .weekday], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        let weekday = weekdaySymbol(for: components.weekday)
        return "\(month)/\(day) \(weekday)"
    }

    private static func resetDayTimeLabel(timestamp: Int, calendar inputCalendar: Calendar) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let components = inputCalendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return "\(resetDayLabel(timestamp: timestamp, calendar: inputCalendar)) \(String(format: "%02d:%02d", hour, minute))"
    }

    private static func weekdaySymbol(for weekday: Int?) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        guard let weekday, (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }
}

struct WeeklyRemainingHistoryPoint: Equatable {
    let recordedAt: Int
    let remainingPercent: Double
    let xPosition: Double
    let isResetAnchor: Bool

    var yPosition: Double {
        min(max(remainingPercent / 100, 0), 1)
    }
}

struct WeeklyRemainingHistoryDayMarker: Equatable, Identifiable {
    let id: Int
    let point: WeeklyRemainingHistoryPoint
    let hoverLabel: String
}

struct WeeklyRemainingHistoryInteraction {
    static let markerHitDiameter: CGFloat = 32
    private static let markerHitRadius: CGFloat = 24

    static func point(for point: WeeklyRemainingHistoryPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(point.xPosition),
            y: size.height * CGFloat(1 - point.yPosition)
        )
    }

    static func nearestMarkerID(
        to location: CGPoint,
        markers: [WeeklyRemainingHistoryDayMarker],
        in size: CGSize,
        hitRadius: CGFloat = markerHitRadius
    ) -> Int? {
        var nearestID: Int?
        var nearestDistance = hitRadius

        for marker in markers {
            let markerPoint = point(for: marker.point, in: size)
            let distance = hypot(markerPoint.x - location.x, markerPoint.y - location.y)
            if distance <= nearestDistance {
                nearestID = marker.id
                nearestDistance = distance
            }
        }

        return nearestID
    }
}

struct PressureBanner: View {
    let message: String
    let phase: UsagePressurePhase

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: phase == .limit ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch phase {
        case .calm:
            .secondary
        case .active:
            .accentColor
        case .fast:
            .orange
        case .sprint, .limit:
            .red
        }
    }
}

struct UsageRow: View {
    let title: String
    let window: UsageWindowReport?
    let resetSummary: String?

    init(
        title: String,
        window: UsageWindowReport?,
        resetSummary: String? = nil
    ) {
        self.title = title
        self.window = window
        self.resetSummary = resetSummary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            RemainingUsageBar(value: progressValue, tint: tint)
                .accessibilityLabel("\(title) 남은 사용량")
                .accessibilityValue(summary)

            if let resetSummary {
                Text("reset \(resetSummary)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

        }
    }

    private var summary: String {
        guard let window else { return "확인 불가" }
        return "\(UsageMonitorState.percent(window.usedPercent))% 사용 / \(UsageMonitorState.percent(window.remainingPercent))% 남음"
    }

    private var progressValue: Double {
        min(max((window?.remainingPercent ?? 0) / 100, 0), 1)
    }

    private var tint: Color {
        switch window?.remainingPercent ?? 0 {
        case ..<10:
            .red
        case 10..<30:
            .orange
        case 30..<60:
            .yellow
        default:
            .green
        }
    }
}

private struct RemainingUsageBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.12))
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: fillWidth(in: proxy.size.width))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: 8)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        guard clamped > 0 else { return 0 }
        return max(4, totalWidth * clamped)
    }
}
