import Darwin
import Foundation

struct SystemMetricsSnapshot: Equatable {
    static let unavailable = SystemMetricsSnapshot(
        capturedAt: Date(),
        cpuLoadPercent: nil,
        memoryUsedPercent: nil,
        diskUsedPercent: nil,
        networkReceivedBytes: nil,
        networkSentBytes: nil,
        activeInterfaceCount: 0,
        battery: .unavailable,
        chargeLimitSupport: .unavailable
    )

    let capturedAt: Date
    let cpuLoadPercent: Double?
    let memoryUsedPercent: Double?
    let diskUsedPercent: Double?
    let networkReceivedBytes: UInt64?
    let networkSentBytes: UInt64?
    let activeInterfaceCount: Int
    let battery: BatteryStatusSnapshot
    let chargeLimitSupport: ChargeLimitSupportSnapshot

    static func capture() -> SystemMetricsSnapshot {
        let network = networkUsage()
        return SystemMetricsSnapshot(
            capturedAt: Date(),
            cpuLoadPercent: cpuLoadPercent(),
            memoryUsedPercent: memoryUsedPercent(),
            diskUsedPercent: diskUsedPercent(),
            networkReceivedBytes: network?.receivedBytes,
            networkSentBytes: network?.sentBytes,
            activeInterfaceCount: network?.activeInterfaceCount ?? 0,
            battery: BatteryStatusSnapshot.capture(),
            chargeLimitSupport: ChargeLimitSupportSnapshot.capture()
        )
    }

    var cpuSummary: String {
        cpuLoadPercent.map { "\(Self.percent($0))% load" } ?? "확인 불가"
    }

    var memorySummary: String {
        memoryUsedPercent.map { "\(Self.percent($0))% 사용" } ?? "확인 불가"
    }

    var diskSummary: String {
        diskUsedPercent.map { "\(Self.percent($0))% 사용" } ?? "확인 불가"
    }

    var networkSummary: String {
        guard let networkReceivedBytes, let networkSentBytes else { return "확인 불가" }
        return "누적 ↓ \(Self.bytes(networkReceivedBytes)) / ↑ \(Self.bytes(networkSentBytes))"
    }

    private static func cpuLoadPercent() -> Double? {
        var averages = [Double](repeating: 0, count: 3)
        guard getloadavg(&averages, Int32(averages.count)) > 0 else { return nil }
        let cores = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        return clamp((averages[0] / Double(cores)) * 100)
    }

    private static func memoryUsedPercent() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize = vm_size_t(0)
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        let availablePages = UInt64(stats.free_count) + UInt64(stats.inactive_count)
        let availableBytes = Double(availablePages * UInt64(pageSize))
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        guard totalBytes > 0 else { return nil }

        return clamp(((totalBytes - availableBytes) / totalBytes) * 100)
    }

    private static func diskUsedPercent() -> Double? {
        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
            let total = attributes[.systemSize] as? NSNumber,
            let free = attributes[.systemFreeSize] as? NSNumber
        else { return nil }

        let totalBytes = total.doubleValue
        let freeBytes = free.doubleValue
        guard totalBytes > 0 else { return nil }
        return clamp(((totalBytes - freeBytes) / totalBytes) * 100)
    }

    private static func networkUsage() -> (receivedBytes: UInt64, sentBytes: UInt64, activeInterfaceCount: Int)? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var activeNames = Set<String>()
        var pointer: UnsafeMutablePointer<ifaddrs>? = interfaces

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = current.pointee.ifa_flags
            guard
                flags & UInt32(IFF_UP) != 0,
                flags & UInt32(IFF_LOOPBACK) == 0,
                let address = current.pointee.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let data = current.pointee.ifa_data
            else { continue }

            let name = String(cString: current.pointee.ifa_name)
            activeNames.insert(name)
            let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
            receivedBytes += UInt64(interfaceData.ifi_ibytes)
            sentBytes += UInt64(interfaceData.ifi_obytes)
        }

        return (receivedBytes, sentBytes, activeNames.count)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 999)
    }

    private static func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private static func bytes(_ value: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var amount = Double(value)
        var unitIndex = 0
        while amount >= 1024, unitIndex < units.count - 1 {
            amount /= 1024
            unitIndex += 1
        }
        if amount.rounded() == amount {
            return "\(Int(amount))\(units[unitIndex])"
        }
        return String(format: "%.1f%@", amount, units[unitIndex])
    }
}
