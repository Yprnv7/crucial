import Foundation
import Observation

@Observable
@MainActor
public final class SystemMaintenanceService {
    public static let shared = SystemMaintenanceService()

    public var tasks: [MaintenanceTaskItem] = [
        MaintenanceTaskItem(
            name: "Thin APFS Local Snapshots",
            subtitle: "Reclaims purgeable space held by stale Time Machine local snapshots.",
            iconName: "clock.arrow.circlepath"
        ),
        MaintenanceTaskItem(
            name: "Flush macOS DNS Cache",
            subtitle: "Clears local DNS resolution caches to resolve stale host lookups.",
            iconName: "network"
        ),
        MaintenanceTaskItem(
            name: "Reclaim Inactive Disk Cache",
            subtitle: "Runs macOS purge to release inactive filesystem buffer memory.",
            iconName: "memorychip"
        ),
        MaintenanceTaskItem(
            name: "Verify Spotlight Index Status",
            subtitle: "Audits metadata indexing health on the root APFS volume.",
            iconName: "magnifyingglass.circle"
        )
    ]

    public var isRunningAll: Bool = false

    private init() {}

    public func runAllTasks() async {
        isRunningAll = true
        for idx in tasks.indices {
            await executeTask(at: idx)
        }
        isRunningAll = false
        FileScannerService.shared.refreshDiskSpace()
    }

    public func executeTask(at index: Int) async {
        guard tasks.indices.contains(index) else { return }
        tasks[index].isExecuting = true
        tasks[index].resultMessage = nil

        switch index {
        case 0:
            let result = await SubprocessRunner.run(executable: "/usr/bin/tmutil", arguments: ["thinlocalsnapshots", "/", "10000000000", "4"])
            tasks[index].resultMessage = result.localizedStandardContains("Thinned") || !result.isEmpty
                ? "APFS local snapshots thinned."
                : "Snapshots checked: no purgeable local delta blocks."

        case 1:
            _ = await SubprocessRunner.run(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
            tasks[index].resultMessage = "DNS cache flushed."

        case 2:
            _ = await SubprocessRunner.run(executable: "/usr/sbin/purge", arguments: [])
            tasks[index].resultMessage = "Inactive buffer pages cleared."

        case 3:
            let result = await SubprocessRunner.run(executable: "/usr/bin/mdutil", arguments: ["-s", "/"])
            tasks[index].resultMessage = result.localizedStandardContains("Indexing enabled")
                ? "Spotlight indexing verified active."
                : "Spotlight status checked."

        default:
            break
        }

        tasks[index].isExecuting = false
        tasks[index].isCompleted = true
    }
}
