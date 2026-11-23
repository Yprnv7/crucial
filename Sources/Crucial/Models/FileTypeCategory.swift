import Foundation
import SwiftUI

public enum FileTypeCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All Files"
    case documents = "Documents & PDFs"
    case images = "Images & Photos"
    case media = "Audio & Video"
    case archives = "Archives & Packages"
    case developer = "Developer & Code"
    case system = "System & Caches"
    case other = "Other Files"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .documents: return "doc.text.fill"
        case .images: return "photo.fill"
        case .media: return "film.fill"
        case .archives: return "archivebox.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .system: return "gearshape.fill"
        case .other: return "doc.fill"
        }
    }

    public var color: Color {
        switch self {
        case .all: return ThingsTheme.accent
        case .documents: return ThingsTheme.infoIndigo
        case .images: return ThingsTheme.purple
        case .media: return Color.pink
        case .archives: return ThingsTheme.starOchre
        case .developer: return ThingsTheme.glacierCyan
        case .system: return Color.gray
        case .other: return ThingsTheme.textSecondary
        }
    }

    public static func categorize(url: URL) -> FileTypeCategory {
        let ext = url.pathExtension.lowercased()
        let path = url.path.lowercased()

        // 1. Documents
        if ["pdf", "doc", "docx", "txt", "rtf", "pages", "md", "markdown", "csv", "xlsx", "xls", "numbers", "ppt", "pptx", "key", "keynote", "epub", "odt"].contains(ext) {
            return .documents
        }

        // 2. Images
        if ["jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "heif", "tiff", "tif", "bmp", "psd", "ai", "raw", "cr2", "nef", "ico"].contains(ext) {
            return .images
        }

        // 3. Audio & Video
        if ["mp4", "mov", "mkv", "avi", "webm", "m4v", "wmv", "flv", "mp3", "wav", "m4a", "flac", "aac", "ogg", "wma", "aiff"].contains(ext) {
            return .media
        }

        // 4. Archives & Packages
        if ["zip", "dmg", "pkg", "tar", "gz", "tgz", "7z", "rar", "iso", "bz2", "xz", "zst"].contains(ext) {
            return .archives
        }

        // 5. Developer & Code
        if ["swift", "py", "ts", "js", "tsx", "jsx", "c", "cpp", "h", "hpp", "m", "mm", "rs", "go", "java", "kt", "rb", "php", "sh", "bash", "zsh", "html", "css", "scss", "json", "yaml", "yml", "xml", "toml", "sql", "graphql", "proto"].contains(ext)
            || path.contains("deriveddata") || path.contains("node_modules") || path.contains(".build") {
            return .developer
        }

        // 6. System & Caches
        if path.hasPrefix("/system") || path.hasPrefix("/library") || path.contains("/caches/") || ["cache", "log", "diag", "crash", "plist", "dylib", "kext", "framework"].contains(ext) {
            return .system
        }

        return .other
    }

    public static func formatDescription(for extensionName: String) -> String {
        let ext = extensionName.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        switch ext {
        case "pdf": return "Portable Document Format (Adobe PDF)"
        case "docx", "doc": return "Microsoft Word Document"
        case "xlsx", "xls": return "Microsoft Excel Spreadsheet"
        case "pptx", "ppt": return "Microsoft PowerPoint Presentation"
        case "pages": return "Apple Pages Document"
        case "key", "keynote": return "Apple Keynote Presentation"
        case "numbers": return "Apple Numbers Spreadsheet"
        case "txt": return "Plain Text Document"
        case "rtf": return "Rich Text Format Document"
        case "md", "markdown": return "Markdown Document"
        case "csv": return "Comma Separated Values Data"
        case "jpg", "jpeg": return "JPEG Photographic Image"
        case "png": return "Portable Network Graphics Image"
        case "webp": return "Google WebP Compressed Image"
        case "heic", "heif": return "Apple High Efficiency Image Container"
        case "gif": return "Graphics Interchange Format Animation"
        case "svg": return "Scalable Vector Graphic"
        case "psd": return "Adobe Photoshop Document"
        case "ai": return "Adobe Illustrator Artwork"
        case "mp4": return "MPEG-4 High-Definition Video"
        case "mov": return "Apple QuickTime Movie"
        case "mkv": return "Matroska Multimedia Container"
        case "mp3": return "MPEG-3 Audio File"
        case "m4a": return "Apple Lossless / AAC Audio"
        case "wav": return "Waveform Uncompressed Audio"
        case "zip": return "Compressed ZIP Archive"
        case "dmg": return "Apple Disk Image Installer"
        case "pkg": return "macOS Installer Package"
        case "tar", "gz": return "Gzip Compressed Tarball"
        case "swift": return "Apple Swift Source Code"
        case "py": return "Python Script"
        case "ts", "tsx": return "TypeScript Source Code"
        case "js", "jsx": return "JavaScript Source Code"
        case "json": return "JavaScript Object Notation Data"
        default: return ".\(ext.uppercased()) File"
        }
    }
}
