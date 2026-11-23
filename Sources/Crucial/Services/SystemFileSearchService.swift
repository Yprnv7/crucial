import Foundation
import AppKit

@MainActor
public final class SystemFileSearchService: ObservableObject {
    public static let shared = SystemFileSearchService()

    @Published public var isSearching: Bool = false
    @Published public var searchResults: [FileItem] = []
    @Published public var lastQuery: String = ""

    private init() {}

    /// Performs a high-speed system-wide search across the Mac using native macOS Spotlight (mdfind)
    /// with direct filesystem fallback for instant results.
    public func search(query: String, maxResults: Int = 150) async -> [FileItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            self.searchResults = []
            self.lastQuery = ""
            self.isSearching = false
            return []
        }

        self.isSearching = true
        self.lastQuery = cleanQuery

        let results = await Task.detached(priority: .userInitiated) { () -> [FileItem] in
            var matchedPaths: [String] = []
            var seenPaths: Set<String> = []

            // 1. Run mdfind for fast spotlight matches
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["-name", cleanQuery]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !seenPaths.contains(trimmed) else { continue }
                        seenPaths.insert(trimmed)
                        matchedPaths.append(trimmed)
                        if matchedPaths.count >= maxResults { break }
                    }
                }
            } catch {
                // If mdfind fails or times out, proceed to user folder fallback
            }

            // 2. Direct fast crawl of primary user directories if mdfind has few results
            if matchedPaths.count < 10 {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let targetDirs = [
                    home.appendingPathComponent("Desktop"),
                    home.appendingPathComponent("Documents"),
                    home.appendingPathComponent("Downloads"),
                    home.appendingPathComponent("Movies"),
                    home.appendingPathComponent("Music")
                ]

                let lowerQ = cleanQuery.lowercased()
                for dir in targetDirs {
                    guard let contents = try? FileManager.default.contentsOfDirectory(
                        at: dir,
                        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    ) else { continue }

                    for fileURL in contents {
                        if fileURL.lastPathComponent.lowercased().contains(lowerQ) {
                            if !seenPaths.contains(fileURL.path) {
                                seenPaths.insert(fileURL.path)
                                matchedPaths.append(fileURL.path)
                                if matchedPaths.count >= maxResults { break }
                            }
                        }
                    }
                    if matchedPaths.count >= maxResults { break }
                }
            }

            // 3. Convert matched paths to rich FileItem models
            var items: [FileItem] = []
            let fm = FileManager.default

            for path in matchedPaths {
                let url = URL(fileURLWithPath: path)
                guard fm.fileExists(atPath: path) else { continue }

                var isDir: ObjCBool = false
                fm.fileExists(atPath: path, isDirectory: &isDir)

                let size: Int64
                if isDir.boolValue {
                    size = calculateFastDirectorySize(at: url)
                } else {
                    let attrs = try? fm.attributesOfItem(atPath: path)
                    size = (attrs?[.size] as? Int64) ?? 0
                }

                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let category = categorizeFile(url: url)
                let assessment = VitalityEngine.shared.assess(url: url, size: size, isDirectory: isDir.boolValue)

                let item = FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    size: size,
                    isDirectory: isDir.boolValue,
                    modificationDate: modDate,
                    category: category,
                    assessment: assessment,
                    isSelected: false
                )
                items.append(item)
            }

            // Sort by size descending
            return items.sorted { $0.size > $1.size }
        }.value

        self.searchResults = results
        self.isSearching = false
        return results
    }

    /// Fast categorized search for specific intent (e.g. CV, Resume, Videos, Documents)
    public func findFiles(matchingKeywords keywords: [String], maxResults: Int = 50) async -> [FileItem] {
        var allFound: [FileItem] = []
        var seenPaths: Set<String> = []

        for kw in keywords {
            let items = await self.search(query: kw, maxResults: maxResults)
            for item in items {
                if !seenPaths.contains(item.path) {
                    seenPaths.insert(item.path)
                    allFound.append(item)
                }
            }
            if allFound.count >= maxResults { break }
        }

        return allFound.sorted { $0.size > $1.size }
    }
}

// MARK: - Non-isolated Search Utilities
private func categorizeFile(url: URL) -> JunkCategory {
    let path = url.path.lowercased()
    let ext = url.pathExtension.lowercased()

    if path.contains("deriveddata") || path.contains("node_modules") || path.contains(".build") || ext == "o" {
        return .devArtifacts
    }
    if path.contains("/caches/") || ext == "cache" || ext == "tmp" {
        return .systemCache
    }
    if path.contains("/logs/") || ext == "log" || ext == "diag" {
        return .systemCache
    }
    if path.contains("/downloads/") || ["zip", "dmg", "pkg", "iso", "tar", "gz"].contains(ext) {
        return .largeUnused
    }
    if path.contains("/application support/") {
        return .appResidue
    }
    return .custom
}

private func calculateFastDirectorySize(at url: URL) -> Int64 {
    var total: Int64 = 0
    guard let contents = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
    ) else {
        return 0
    }
    for fileURL in contents.prefix(150) {
        if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            total += Int64(size)
        }
    }
    return total
}
