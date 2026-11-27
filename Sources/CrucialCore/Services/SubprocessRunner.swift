import Foundation
import os

/// Clean Swift Concurrency wrapper over `Process` without GCD callbacks or blocking waits on the main actor.
public enum SubprocessRunner: Sendable {
    private static let logger = Logger(subsystem: "com.crucial.cleaner", category: "SubprocessRunner")

    public nonisolated static func run(executable: String, arguments: [String]) async -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            logger.error("Executable missing at path: \(executable, privacy: .public)")
            return ""
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let resumed = OSAllocatedUnfairLock(initialState: false)
            let buffer = OSAllocatedUnfairLock(initialState: Data())

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    buffer.withLock { $0.append(chunk) }
                }
            }

            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let data = buffer.withLock { stored -> Data in
                    var combined = stored
                    combined.append(remaining)
                    return combined
                }
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                if !alreadyResumed {
                    let output = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: output)
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                logger.error("Failed to launch \(executable, privacy: .public): \(error.localizedDescription, privacy: .public)")
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                if !alreadyResumed {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    public nonisolated static func runData(executable: String, arguments: [String]) async -> Data {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            return Data()
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            let resumed = OSAllocatedUnfairLock(initialState: false)
            let buffer = OSAllocatedUnfairLock(initialState: Data())

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    buffer.withLock { $0.append(chunk) }
                }
            }

            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let data = buffer.withLock { stored -> Data in
                    var combined = stored
                    combined.append(remaining)
                    return combined
                }
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                if !alreadyResumed {
                    continuation.resume(returning: data)
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                if !alreadyResumed {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    /// Streams incremental UTF-8 tokens from a long-running process on a cooperative background worker.
    public nonisolated static func stream(
        executable: String,
        arguments: [String],
        onChunk: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            return -1
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            let resumed = OSAllocatedUnfairLock(initialState: false)

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    onChunk(text)
                }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let trailing = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !trailing.isEmpty, let text = String(data: trailing, encoding: .utf8), !text.isEmpty {
                    onChunk(text)
                }
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                if !alreadyResumed {
                    continuation.resume(returning: proc.terminationStatus)
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                if !alreadyResumed {
                    continuation.resume(returning: -1)
                }
            }
        }
    }
}
