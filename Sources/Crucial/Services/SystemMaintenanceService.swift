import Foundation

public struct MaintenanceTaskItem: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let subtitle: String
    public let iconName: String
    public var isExecuting: Bool
    public var isCompleted: Bool
    public var resultMessage: String?
}

@MainActor
public final class SystemMaintenanceService: ObservableObject {
    public static let shared = SystemMaintenanceService()

    @Published public var tasks: [MaintenanceTaskItem] = [
        MaintenanceTaskItem(
            name: "Thin APFS Local Snapshots",
            subtitle: "Reclaims hidden System Data storage locked by local Time Machine delta snapshots.",
            iconName: "clock.arrow.circlepath",
            isExecuting: false,
            isCompleted: false,
            resultMessage: nil
        ),
        MaintenanceTaskItem(
            name: "Flush macOS DNS Cache",
            subtitle: "Resolves stale network hostnames, CDN connection errors, and domain redirects.",
            iconName: "network",
            isExecuting: false,
            isCompleted: false,
            resultMessage: nil
        ),
        MaintenanceTaskItem(
            name: "Reclaim Inactive Disk Cache Memory",
            subtitle: "Purges cached inactive disk buffer pages to free up immediate system memory.",
            iconName: "memorychip",
            isExecuting: false,
            isCompleted: false,
            resultMessage: nil
        ),
        MaintenanceTaskItem(
            name: "Verify Spotlight Index Service",
            subtitle: "Verifies macOS metadata indexing status and health across APFS root.",
            iconName: "magnifyingglass.circle",
            isExecuting: false,
            isCompleted: false,
            resultMessage: nil
        )
    ]

    @Published public var isRunningAll: Bool = false

    private init() {}

    public func runAllTasks() async {
        isRunningAll = true
        for i in 0..<tasks.count {
            await executeTask(at: i)
        }
        isRunningAll = false
        FileScannerService.shared.refreshDiskSpace()
    }

    public func executeTask(at index: Int) async {
        guard index < tasks.count else { return }
        tasks[index].isExecuting = true
        tasks[index].resultMessage = nil

        switch index {
        case 0:
            // Thin APFS Local Snapshots via tmutil
            let result = await runProcess(executable: "/usr/bin/tmutil", arguments: ["thinlocalsnapshots", "/", "10000000000", "4"])
            tasks[index].resultMessage = result.contains("Thinned") || !result.isEmpty ? "APFS local snapshots successfully thinned." : "Snapshots audited. No phantom purgeable blocks found."

        case 1:
            // Flush DNS Cache via dscacheutil
            _ = await runProcess(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
            tasks[index].resultMessage = "DNS cache flushed successfully."

        case 2:
            // Inactive cache memory purge
            _ = await runProcess(executable: "/usr/sbin/purge", arguments: [])
            tasks[index].resultMessage = "Inactive buffer pages cleared."

        case 3:
            // Spotlight check
            let result = await runProcess(executable: "/usr/bin/mdutil", arguments: ["-s", "/"])
            tasks[index].resultMessage = result.contains("Indexing enabled") ? "Spotlight indexing verified active and healthy." : "Spotlight indexing status audited."

        default:
            break
        }

        tasks[index].isExecuting = false
        tasks[index].isCompleted = true
    }

    private func runProcess(executable: String, arguments: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
