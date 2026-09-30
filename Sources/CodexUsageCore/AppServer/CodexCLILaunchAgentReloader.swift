import Darwin
import Foundation

/// Reloads the usage-cache agent after its plist changes.
/// The reload runs in a new session so bootout cannot kill it before bootstrap.
enum CodexCLILaunchAgentReloader {
    static func schedule(plistURL: URL, label: String) {
        let target = "gui/\(getuid())"
        let service = "\(target)/\(label)"
        let script = """
        sleep 1
        if /bin/launchctl print \(shellQuote(service)) >/dev/null 2>&1; then
          /bin/launchctl bootout \(shellQuote(service)) >/dev/null 2>&1 || true
          /bin/launchctl bootstrap \(shellQuote(target)) \(shellQuote(plistURL.path)) >/dev/null 2>&1 || true
        fi
        """
        spawnDetached(script: script)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func spawnDetached(script: String) {
        var pid: pid_t = 0
        var attr: posix_spawnattr_t?
        guard posix_spawnattr_init(&attr) == 0 else { return }
        defer { posix_spawnattr_destroy(&attr) }
        guard posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID)) == 0 else { return }
        script.withCString { scriptPointer in
            "/bin/sh".withCString { shell in
                "-c".withCString { flag in
                    var arguments: [UnsafeMutablePointer<CChar>?] = [
                        UnsafeMutablePointer(mutating: shell),
                        UnsafeMutablePointer(mutating: flag),
                        UnsafeMutablePointer(mutating: scriptPointer),
                        nil
                    ]
                    _ = posix_spawn(&pid, "/bin/sh", nil, &attr, &arguments, environ)
                }
            }
        }
    }
}
