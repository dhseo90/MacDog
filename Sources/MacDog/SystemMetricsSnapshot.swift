import Darwin
import Foundation

struct SystemMetricsSnapshot: Equatable {
    static let unavailable = SystemMetricsSnapshot(
        capturedAt: Date(),
        cpuLoadPercent: nil,
        memoryUsedPercent: nil,
        memoryDetails: nil,
        diskUsedPercent: nil,
        networkReceivedBytes: nil,
        networkSentBytes: nil,
        networkReceivedRateBytesPerSecond: nil,
        networkSentRateBytesPerSecond: nil,
        activeInterfaceCount: 0,
        primaryNetworkInterfaceName: nil,
        localIPAddress: nil,
        cpuBreakdown: nil,
        battery: .unavailable,
        chargeLimitSupport: .unavailable
    )

    let capturedAt: Date
    let cpuLoadPercent: Double?
    let memoryUsedPercent: Double?
    let memoryDetails: MemoryDetailsSnapshot?
    let diskUsedPercent: Double?
    let networkReceivedBytes: UInt64?
    let networkSentBytes: UInt64?
    let networkReceivedRateBytesPerSecond: Double?
    let networkSentRateBytesPerSecond: Double?
    let activeInterfaceCount: Int
    let primaryNetworkInterfaceName: String?
    let localIPAddress: String?
    let cpuBreakdown: CPUUsageBreakdown?
    let battery: BatteryStatusSnapshot
    let chargeLimitSupport: ChargeLimitSupportSnapshot

    static func capture() -> SystemMetricsSnapshot {
        let network = networkUsage()
        let memory = memoryDetails()
        return SystemMetricsSnapshot(
            capturedAt: Date(),
            cpuLoadPercent: cpuLoadPercent(),
            memoryUsedPercent: memory?.usedPercent,
            memoryDetails: memory,
            diskUsedPercent: diskUsedPercent(),
            networkReceivedBytes: network?.receivedBytes,
            networkSentBytes: network?.sentBytes,
            networkReceivedRateBytesPerSecond: network?.receivedRateBytesPerSecond,
            networkSentRateBytesPerSecond: network?.sentRateBytesPerSecond,
            activeInterfaceCount: network?.activeInterfaceCount ?? 0,
            primaryNetworkInterfaceName: network?.primaryInterfaceName,
            localIPAddress: network?.localIPAddress,
            cpuBreakdown: cpuBreakdown(),
            battery: BatteryStatusSnapshot.capture(),
            chargeLimitSupport: ChargeLimitSupportSnapshot.capture()
        )
    }

    var cpuSummary: String {
        cpuLoadPercent.map { "\(Self.percent($0))% load" } ?? "확인 불가"
    }

    var cpuDetailSummary: String {
        guard let cpuBreakdown else { return "확인 불가" }
        return "시스템 \(Self.percent(cpuBreakdown.systemPercent)) · 사용자 \(Self.percent(cpuBreakdown.userPercent)) · 대기 \(Self.percent(cpuBreakdown.idlePercent))"
    }

    var memorySummary: String {
        memoryUsedPercent.map { "\(Self.percent($0))% 사용" } ?? "확인 불가"
    }

    var memoryDetailSummary: String {
        guard let memoryDetails else { return "확인 불가" }
        return "앱 \(Self.bytes(memoryDetails.appMemoryBytes)) · 와이어드 \(Self.bytes(memoryDetails.wiredMemoryBytes)) · 압축 \(Self.bytes(memoryDetails.compressedMemoryBytes))"
    }

    var diskSummary: String {
        diskUsedPercent.map { "\(Self.percent($0))% 사용" } ?? "확인 불가"
    }

    var networkSummary: String {
        guard let networkReceivedBytes, let networkSentBytes else { return "확인 불가" }
        return "누적 ↓ \(Self.bytes(networkReceivedBytes)) / ↑ \(Self.bytes(networkSentBytes))"
    }

    var networkRateSummary: String {
        guard let networkReceivedRateBytesPerSecond, let networkSentRateBytesPerSecond else {
            return "속도 산정 중"
        }
        return "↓ \(Self.bytesPerSecond(networkReceivedRateBytesPerSecond)) · ↑ \(Self.bytesPerSecond(networkSentRateBytesPerSecond))"
    }

    var localNetworkSummary: String {
        guard let localIPAddress else { return "확인 불가" }
        if let primaryNetworkInterfaceName {
            return "\(primaryNetworkInterfaceName) · \(localIPAddress)"
        }
        return localIPAddress
    }

    private static func cpuLoadPercent() -> Double? {
        var averages = [Double](repeating: 0, count: 3)
        guard getloadavg(&averages, Int32(averages.count)) > 0 else { return nil }
        let cores = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        return clamp((averages[0] / Double(cores)) * 100)
    }

    private static func cpuBreakdown() -> CPUUsageBreakdown? {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let user = Double(loadInfo.cpu_ticks.0 + loadInfo.cpu_ticks.3)
        let system = Double(loadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2)
        let total = user + system + idle
        guard total > 0 else { return nil }

        return CPUUsageBreakdown(
            userPercent: clamp((user / total) * 100),
            systemPercent: clamp((system / total) * 100),
            idlePercent: clamp((idle / total) * 100)
        )
    }

    private static func memoryDetails() -> MemoryDetailsSnapshot? {
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

        let pageBytes = UInt64(pageSize)
        return MemoryDetailsSnapshot(
            usedPercent: clamp(((totalBytes - availableBytes) / totalBytes) * 100),
            appMemoryBytes: UInt64(stats.active_count) * pageBytes,
            wiredMemoryBytes: UInt64(stats.wire_count) * pageBytes,
            compressedMemoryBytes: UInt64(stats.compressor_page_count) * pageBytes
        )
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

    private static func networkUsage() -> (
        receivedBytes: UInt64,
        sentBytes: UInt64,
        receivedRateBytesPerSecond: Double?,
        sentRateBytesPerSecond: Double?,
        activeInterfaceCount: Int,
        primaryInterfaceName: String?,
        localIPAddress: String?
    )? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var activeNames = Set<String>()
        var localAddresses: [String: String] = [:]
        var pointer: UnsafeMutablePointer<ifaddrs>? = interfaces

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = current.pointee.ifa_flags
            guard
                flags & UInt32(IFF_UP) != 0,
                flags & UInt32(IFF_LOOPBACK) == 0,
                let address = current.pointee.ifa_addr
            else { continue }

            let name = String(cString: current.pointee.ifa_name)
            let family = Int32(address.pointee.sa_family)

            if family == AF_LINK, let data = current.pointee.ifa_data {
                activeNames.insert(name)
                let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
                receivedBytes += UInt64(interfaceData.ifi_ibytes)
                sentBytes += UInt64(interfaceData.ifi_obytes)
            } else if family == AF_INET || family == AF_INET6 {
                if localAddresses[name] == nil, let ipAddress = ipAddress(from: address) {
                    localAddresses[name] = ipAddress
                }
            }
        }

        let rate = networkRateSampler.update(
            receivedBytes: receivedBytes,
            sentBytes: sentBytes,
            capturedAt: Date().timeIntervalSince1970
        )
        let primaryName = preferredInterfaceName(from: localAddresses, activeNames: activeNames)
        return (
            receivedBytes,
            sentBytes,
            rate?.receivedBytesPerSecond,
            rate?.sentBytesPerSecond,
            activeNames.count,
            primaryName,
            primaryName.flatMap { localAddresses[$0] }
        )
    }

    private static func preferredInterfaceName(from localAddresses: [String: String], activeNames: Set<String>) -> String? {
        let candidates = localAddresses.keys.filter { activeNames.contains($0) }.sorted()
        return candidates.first { $0.hasPrefix("en") } ?? candidates.first
    }

    private static func ipAddress(from address: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(address.pointee.sa_len)
        let result = getnameinfo(
            address,
            length,
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let value = String(decoding: bytes, as: UTF8.self)
        return value.contains("%") ? nil : value
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

    private static func bytesPerSecond(_ value: Double) -> String {
        "\(bytes(UInt64(max(value, 0))))/s"
    }

    private static let networkRateSampler = NetworkRateSampler()
}

struct CPUUsageBreakdown: Equatable {
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
}

struct MemoryDetailsSnapshot: Equatable {
    let usedPercent: Double
    let appMemoryBytes: UInt64
    let wiredMemoryBytes: UInt64
    let compressedMemoryBytes: UInt64
}

private final class NetworkRateSampler: @unchecked Sendable {
    private struct Sample {
        let receivedBytes: UInt64
        let sentBytes: UInt64
        let capturedAt: TimeInterval
    }

    private let lock = NSLock()
    private var previousSample: Sample?

    func update(
        receivedBytes: UInt64,
        sentBytes: UInt64,
        capturedAt: TimeInterval
    ) -> (receivedBytesPerSecond: Double, sentBytesPerSecond: Double)? {
        lock.lock()
        defer { lock.unlock() }

        defer {
            previousSample = Sample(
                receivedBytes: receivedBytes,
                sentBytes: sentBytes,
                capturedAt: capturedAt
            )
        }

        guard let previousSample else { return nil }
        let elapsed = capturedAt - previousSample.capturedAt
        guard elapsed > 0.5 else { return nil }

        let receivedDelta = receivedBytes >= previousSample.receivedBytes
            ? receivedBytes - previousSample.receivedBytes
            : 0
        let sentDelta = sentBytes >= previousSample.sentBytes
            ? sentBytes - previousSample.sentBytes
            : 0

        return (
            Double(receivedDelta) / elapsed,
            Double(sentDelta) / elapsed
        )
    }
}
