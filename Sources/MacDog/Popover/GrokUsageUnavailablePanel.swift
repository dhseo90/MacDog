import SwiftUI

struct GrokUsageUnavailablePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grok 사용량")
                .font(.headline)
            Text("현재 제공되지 않음")
                .font(.caption.weight(.semibold))
            Text("주간 cache가 아직 없습니다. Codex cache로 대체하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
