import AppKit
import Foundation

enum SystemSettingsDestination {
    static let batterySettingsURLCandidates = [
        URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension"),
        URL(string: "x-apple.systempreferences:com.apple.preference.battery"),
        URL(fileURLWithPath: "/System/Applications/System Settings.app")
    ].compactMap { $0 }

    static let lockScreenSettingsURLCandidates = [
        URL(string: "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension"),
        URL(string: "x-apple.systempreferences:com.apple.preference.security?General"),
        URL(fileURLWithPath: "/System/Applications/System Settings.app")
    ].compactMap { $0 }

    static func openBatterySettings(workspace: NSWorkspace = .shared) -> Bool {
        for url in batterySettingsURLCandidates where workspace.open(url) {
            return true
        }

        return false
    }

    static func openLockScreenSettings(workspace: NSWorkspace = .shared) -> Bool {
        for url in lockScreenSettingsURLCandidates where workspace.open(url) {
            return true
        }

        return false
    }
}
