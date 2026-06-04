import SwiftUI

struct BatteryPanel: View {
    let snapshot: SystemMetricsSnapshot

    @AppStorage(RunnerPreferences.chargeLimitTargetPercentKey) private var chargeLimitTargetPercent = RunnerPreferences.defaultChargeLimitTargetPercent
    @State private var appliedChargeLimitPercent: Int?
    @State private var chargeLimitErrorMessage: String?

    private let chargeLimitController = NativeChargeLimitController()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResourceMetricBlock(
                title: "배터리",
                systemImage: "battery.100percent",
                value: snapshot.battery.summary,
                details: [
                    snapshot.battery.powerSummary
                ],
                progress: snapshot.battery.percent.map { Double($0) / 100 }
            )

            Divider()

            PopoverFormSection(title: "배터리 정보", systemImage: "info.circle") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        metricRow("사이클", snapshot.battery.cycleSummary)
                    }
                    GridRow {
                        metricRow("온도", snapshot.battery.temperatureSummary)
                    }
                }
            }

            Divider()

            PopoverFormSection(title: "충전 제어", systemImage: "slider.horizontal.3") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        metricRow("현재 한도", chargeLimitSummary)
                    }
                    if !snapshot.chargeLimitSupport.isNativeChargeLimitAvailable {
                        GridRow {
                            metricRow("필요 조건", snapshot.chargeLimitSupport.requirementSummary)
                        }
                    }
                    GridRow {
                        metricRow("설정값", "\(effectiveChargeLimitTargetPercent)%", emphasized: true)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("\(RunnerPreferences.minimumChargeLimitTargetPercent)%")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("\(RunnerPreferences.maximumChargeLimitTargetPercent)%")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)

                    Slider(
                        value: chargeLimitTargetBinding,
                        in: Double(chargeLimitRange.lowerBound)...Double(chargeLimitRange.upperBound),
                        step: Double(RunnerPreferences.chargeLimitTargetStepPercent)
                    )
                    .disabled(!snapshot.chargeLimitSupport.isNativeChargeLimitAvailable)
                }

                Text(snapshot.chargeLimitSupport.guidanceSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let chargeLimitErrorMessage {
                    Text(chargeLimitErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            appliedChargeLimitPercent = snapshot.chargeLimitSupport.currentLimitPercent
        }
    }

    private var chargeLimitSummary: String {
        if let appliedChargeLimitPercent {
            return "\(appliedChargeLimitPercent)% 적용됨"
        }
        if let currentLimitPercent = snapshot.chargeLimitSupport.currentLimitPercent {
            return "\(currentLimitPercent)% 적용됨"
        }
        return snapshot.chargeLimitSupport.summary
    }

    private var effectiveChargeLimitTargetPercent: Int {
        RunnerPreferences.normalizedChargeLimitTargetPercent(
            appliedChargeLimitPercent ?? snapshot.chargeLimitSupport.currentLimitPercent ?? chargeLimitTargetPercent
        )
    }

    private var chargeLimitRange: ClosedRange<Int> {
        guard
            let lowerBound = snapshot.chargeLimitSupport.availableLimits.first,
            let upperBound = snapshot.chargeLimitSupport.availableLimits.last
        else {
            return RunnerPreferences.minimumChargeLimitTargetPercent...RunnerPreferences.maximumChargeLimitTargetPercent
        }
        return lowerBound...upperBound
    }

    private var chargeLimitTargetBinding: Binding<Double> {
        Binding(
            get: {
                Double(effectiveChargeLimitTargetPercent)
            },
            set: { newValue in
                let percent = RunnerPreferences.normalizedChargeLimitTargetPercent(Int(newValue.rounded()))
                do {
                    let appliedPercent = try chargeLimitController.setLimitPercent(percent)
                    RunnerPreferences.setChargeLimitTargetPercent(appliedPercent)
                    chargeLimitTargetPercent = appliedPercent
                    appliedChargeLimitPercent = appliedPercent
                    chargeLimitErrorMessage = nil
                } catch {
                    chargeLimitErrorMessage = "적용 실패 · \(error.localizedDescription)"
                }
            }
        )
    }

    private func metricRow(_ key: String, _ value: String, emphasized: Bool = false) -> some View {
        GridRow {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(emphasized ? .callout.weight(.bold) : .caption)
                .monospacedDigit()
                .foregroundStyle(emphasized ? Color.accentColor : Color.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
