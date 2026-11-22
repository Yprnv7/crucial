import Foundation
import Darwin

@MainActor
public final class CPUMonitorService: ObservableObject {
    public static let shared = CPUMonitorService()

    @Published public var cpuPercent: Double = 0.0
    @Published public var memoryMB: Double = 0.0

    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMetrics()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func refreshMetrics() {
        self.cpuPercent = Self.readProcessCPU()
        self.memoryMB = Self.readProcessMemoryMB()
    }

    public static func readProcessCPU() -> Double {
        var threadsList: thread_act_array_t?
        var threadsCount: mach_msg_type_number_t = 0
        let result = task_threads(mach_task_self_, &threadsList, &threadsCount)
        guard result == KERN_SUCCESS, let threadsList else { return 0.0 }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadsList)),
                vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride)
            )
        }

        var totalUsage: Double = 0.0
        for i in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let kr = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadsList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            if kr == KERN_SUCCESS {
                if (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                    totalUsage += (Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                }
            }
        }
        return min(max(totalUsage, 0.0), 800.0) // Return real percent
    }

    public static func readProcessMemoryMB() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kr = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / (1024.0 * 1024.0)
        }
        return 0.0
    }
}
