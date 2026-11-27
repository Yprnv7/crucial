import Observation
import Foundation

@Observable
@MainActor
public final class NavigationStore {
    public static let shared = NavigationStore()

    public var selectedNav: CrucialNavSection = .dashboard
    public var selectedItem: FileItem?
    public var activeSearchQuery: String = ""
    public var quickLookURL: URL?

    public var sidebarSelection: CrucialNavSection? {
        get { selectedNav }
        set {
            if let newValue {
                selectedNav = newValue
            }
        }
    }

    private init() {}

    public func navigate(to section: CrucialNavSection, item: FileItem? = nil) {
        selectedNav = section
        if let item {
            selectedItem = item
        }
    }

    public func openCategory(_ category: JunkCategory) {
        navigate(to: .category(category))
    }

    public func preview(_ url: URL) {
        quickLookURL = url
    }
}
