import MacDogPrivilegedHelperSupport

struct PrivilegedHelperPopoverAction: Equatable, Identifiable {
    let title: String
    let systemImage: String
    let action: PetAction

    var id: String { title }

    static func actions(for snapshot: PrivilegedHelperInstallSnapshot) -> [PrivilegedHelperPopoverAction] {
        switch snapshot.status {
        case .missing:
            [
                PrivilegedHelperPopoverAction(
                    title: "도우미 설치",
                    systemImage: "plus.circle",
                    action: .installPrivilegedHelper
                )
            ]
        case .partial:
            [
                PrivilegedHelperPopoverAction(
                    title: "제거",
                    systemImage: "trash",
                    action: .uninstallPrivilegedHelper
                ),
                PrivilegedHelperPopoverAction(
                    title: "다시 설치",
                    systemImage: "arrow.clockwise",
                    action: .installPrivilegedHelper
                )
            ]
        case .installed:
            [
                PrivilegedHelperPopoverAction(
                    title: "도우미 제거",
                    systemImage: "trash",
                    action: .uninstallPrivilegedHelper
                )
            ]
        }
    }
}
