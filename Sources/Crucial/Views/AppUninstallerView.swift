import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct AppUninstallerView: View {
    @ObservedObject var uninstaller = AppUninstallerService.shared
    @State private var searchText = ""
    @State private var selectedFilter: AppFilterCategory = .all
    @State private var showingUninstallConfirmation = false
    @State private var isTargetedForDrop = false
    @State private var isPerformingUninstall = false

    public enum AppFilterCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case user = "User Apps"
        case running = "Running"
        case protected = "Protected"

        public var id: String { rawValue }
    }

    public init() {}

    private var filteredApps: [InstalledAppInfo] {
        var list = uninstaller.installedApps

        switch selectedFilter {
        case .all:
            break
        case .user:
            list = list.filter { !$0.isSystemProtected }
        case .running:
            list = list.filter { $0.isRunning }
        case .protected:
            list = list.filter { $0.isSystemProtected }
        }

        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.bundleIdentifier.lowercased().contains(query)
            }
        }
        return list
    }

    public var body: some View {
        ZStack {
            HSplitView {
            // MARK: - Left Pane: App List & Filter
            VStack(spacing: 0) {
                // Header & Action Bar
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(ThingsTheme.accent.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ThingsTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("App Uninstaller")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ThingsTheme.textPrimary)
                            Text("\(uninstaller.installedApps.count) applications detected")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            Task {
                                await uninstaller.scanInstalledApplications()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundStyle(ThingsTheme.textSecondary)
                                .padding(6)
                                .background(ThingsTheme.cardRaised)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Rescan installed applications")
                    }

                    // Search Field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textTertiary)
                        TextField("Filter apps by name or bundle ID...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ThingsTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(ThingsTheme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(ThingsTheme.border, lineWidth: 1)
                    )

                    // Filter Segment Chips
                    HStack(spacing: 4) {
                        ForEach(AppFilterCategory.allCases) { category in
                            let isSelected = selectedFilter == category
                            let count = countForCategory(category)
                            Button {
                                selectedFilter = category
                            } label: {
                                HStack(spacing: 3) {
                                    Text(category.rawValue)
                                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                    Text("\(count)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : ThingsTheme.textTertiary)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(isSelected ? ThingsTheme.accent : ThingsTheme.cardRaised)
                                .foregroundStyle(isSelected ? Color.white : ThingsTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(ThingsTheme.sidebar)

                Divider().background(ThingsTheme.borderSubtle)

                // Drag & Drop Dropzone Banner
                HStack(spacing: 8) {
                    Image(systemName: isTargetedForDrop ? "arrow.down.app.fill" : "arrow.down.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isTargetedForDrop ? ThingsTheme.accent : ThingsTheme.textTertiary)
                    Text(isTargetedForDrop ? "Drop .app to inspect residue" : "Drag and drop any .app here to inspect residue")
                        .font(.system(size: 10.5))
                        .foregroundStyle(isTargetedForDrop ? ThingsTheme.accent : ThingsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isTargetedForDrop ? ThingsTheme.accent.opacity(0.12) : ThingsTheme.cardRaised.opacity(0.4))
                .animation(.easeInOut(duration: 0.2), value: isTargetedForDrop)

                Divider().background(ThingsTheme.borderSubtle)

                // Apps Scrollable List
                if uninstaller.isScanning {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(0.8)
                        Text(uninstaller.progressMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredApps.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(ThingsTheme.textTertiary)
                        Text("No applications found")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThingsTheme.textSecondary)
                        if !searchText.isEmpty {
                            Button("Clear Filter") { searchText = ""; selectedFilter = .all }
                                .font(.system(size: 11))
                                .buttonStyle(.plain)
                                .foregroundStyle(ThingsTheme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredApps) { app in
                                appRow(app)
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minWidth: 320, maxWidth: 420)
            .onDrop(of: [UTType.fileURL.identifier, "public.file-url", UTType.application.identifier], isTargeted: $isTargetedForDrop) { providers in
                handleDrop(providers: providers)
            }

            // MARK: - Right Pane: Residue Inspection & Trashing
            VStack(spacing: 0) {
                if let app = uninstaller.selectedApp {
                    appDetailPane(app)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 40))
                            .foregroundStyle(ThingsTheme.textTertiary)
                        Text("Select an Application")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textPrimary)
                        Text("Crucial will trace its container, cache stores, preferences, and launch agents.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ThingsTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 460, maxWidth: .infinity)
            .background(ThingsTheme.canvas)
        }

        // In-Window Things 3 Confirmation Modal Overlay
        if showingUninstallConfirmation, let app = uninstaller.selectedApp {
            Color.black.opacity(0.45)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isPerformingUninstall {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showingUninstallConfirmation = false
                        }
                    }
                }

            uninstallConfirmationCard(app: app)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(100)
        }
    }
    .onAppear {
        if uninstaller.installedApps.isEmpty && !uninstaller.isScanning {
            Task {
                await uninstaller.scanInstalledApplications()
            }
        }
    }
}

    private func countForCategory(_ category: AppFilterCategory) -> Int {
        switch category {
        case .all:
            return uninstaller.installedApps.count
        case .user:
            return uninstaller.installedApps.filter { !$0.isSystemProtected }.count
        case .running:
            return uninstaller.installedApps.filter { $0.isRunning }.count
        case .protected:
            return uninstaller.installedApps.filter { $0.isSystemProtected }.count
        }
    }

    // MARK: - Left Pane Row
    private func appRow(_ app: InstalledAppInfo) -> some View {
        let isSelected = uninstaller.selectedApp?.id == app.id

        return Button {
            uninstaller.selectApp(app)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(app.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textPrimary)
                            .lineLimit(1)

                        if app.isRunning {
                            Circle()
                                .fill(ThingsTheme.starOchre)
                                .frame(width: 6, height: 6)
                                .help("Application is currently running")
                        }
                    }

                    HStack(spacing: 4) {
                        if app.isSystemProtected {
                            Text("System Protected")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(ThingsTheme.textTertiary)
                        } else {
                            Text("v\(app.version)")
                                .font(.system(size: 9.5))
                                .foregroundStyle(ThingsTheme.textTertiary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? ThingsTheme.accent : ThingsTheme.textPrimary)

                    if !app.residueItems.isEmpty {
                        Text("\(app.residueItems.count) residue")
                            .font(.system(size: 9))
                            .foregroundStyle(ThingsTheme.accent)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? ThingsTheme.cardRaised : ThingsTheme.card.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? ThingsTheme.accent.opacity(0.7) : ThingsTheme.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right Detail Pane
    private func appDetailPane(_ app: InstalledAppInfo) -> some View {
        VStack(spacing: 0) {
            // App Header Card
            HStack(spacing: 16) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ThingsTheme.textPrimary)

                        ThingsTag("v\(app.version)", color: ThingsTheme.infoIndigo)

                        if app.isRunning {
                            ThingsTag("Running", color: ThingsTheme.starOchre)
                        }

                        if app.isSystemProtected {
                            ThingsTag("Protected", color: ThingsTheme.textTertiary)
                        } else {
                            ThingsTag("User App", color: ThingsTheme.accent)
                        }
                    }

                    Text(app.bundleIdentifier.isEmpty ? "No bundle identifier" : app.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)

                    Text(app.bundleURL.path)
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedReclaimableSize)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ThingsTheme.accent)

                    Text("\(app.checkedResidueCount + (app.isBundleSelected && !app.isSystemProtected ? 1 : 0)) items selected")
                        .font(.system(size: 10))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
            }
            .padding(18)
            .background(ThingsTheme.card)

            Divider().background(ThingsTheme.borderSubtle)

            // Status Banners & Warnings
            if let result = uninstaller.lastResult, result.appName == app.name {
                HStack(spacing: 8) {
                    Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(result.succeeded ? ThingsTheme.accent : ThingsTheme.vitalCrimson)
                    Text(result.succeeded ?
                         "Moved \(result.itemsTrashed) items to macOS Trash (freed \(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file)))." :
                         (result.errorMessage ?? "Failed to move files to Trash."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThingsTheme.textPrimary)
                    Spacer()
                    Button {
                        uninstaller.lastResult = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(ThingsTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(result.succeeded ? ThingsTheme.accent.opacity(0.1) : ThingsTheme.vitalCrimson.opacity(0.1))
                Divider().background(ThingsTheme.borderSubtle)
            }

            if app.isSystemProtected {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ThingsTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("System Protected Application")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textPrimary)
                        Text(app.protectionReason ?? "This application cannot be uninstalled because it is protected by macOS.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(ThingsTheme.cardRaised)
                Divider().background(ThingsTheme.borderSubtle)
            } else if app.isRunning {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ThingsTheme.starOchre)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Application is Active")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textPrimary)
                        Text("\(app.name) is currently open in memory. Quit it before moving files to Trash.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            _ = await uninstaller.quitApplication(app)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if uninstaller.isQuittingApp {
                                ProgressView().scaleEffect(0.6)
                            }
                            Text("Quit App")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ThingsTheme.starOchre.opacity(0.15))
                        .foregroundStyle(ThingsTheme.starOchre)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(uninstaller.isQuittingApp)
                }
                .padding(12)
                .background(ThingsTheme.starOchre.opacity(0.08))
                Divider().background(ThingsTheme.borderSubtle)
            }

            // Package & Residue Breakdown List
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("FILES TO RECLAIM")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(ThingsTheme.textTertiary)
                            .tracking(0.5)

                        Spacer()

                        if !app.residueItems.isEmpty {
                            Button("Select All") {
                                uninstaller.toggleAllResidue(appID: app.id, checked: true)
                            }
                            .font(.system(size: 10, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(ThingsTheme.accent)

                            Text("•").font(.system(size: 8)).foregroundStyle(ThingsTheme.textTertiary)

                            Button("Deselect All") {
                                uninstaller.toggleAllResidue(appID: app.id, checked: false)
                            }
                            .font(.system(size: 10, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(ThingsTheme.textSecondary)
                        }
                    }

                    // 1. Application Bundle Row
                    bundleRow(app)

                    // 2. Residue Items List
                    if app.residueItems.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ThingsTheme.accent)
                            Text("No external Application Support, Cache, or Container clutter detected.")
                                .font(.system(size: 11))
                                .foregroundStyle(ThingsTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ThingsTheme.cardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ForEach(app.residueItems) { item in
                            residueRow(app: app, item: item)
                        }
                    }
                }
                .padding(18)
            }

            Divider().background(ThingsTheme.borderSubtle)

            // Action Footer
            HStack {
                Button {
                    NSWorkspace.shared.selectFile(app.bundleURL.path, inFileViewerRootedAtPath: "")
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Reveal in Finder")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ThingsTheme.cardRaised)
                    .foregroundStyle(ThingsTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()

                if app.isSystemProtected {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("System Protected (Cannot Uninstall)")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ThingsTheme.cardRaised)
                    .foregroundStyle(ThingsTheme.textTertiary)
                    .clipShape(Capsule())
                } else if app.isRunning {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            showingUninstallConfirmation = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Quit & Move to Trash (\(app.formattedReclaimableSize))")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ThingsTheme.starOchre)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(app.reclaimableBytes == 0 || isPerformingUninstall)
                } else {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            showingUninstallConfirmation = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isPerformingUninstall {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(app.isBundleSelected ? "Uninstall (\(app.formattedReclaimableSize))" : "Clean Residue (\(app.formattedReclaimableSize))")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(app.reclaimableBytes > 0 ? ThingsTheme.accent : ThingsTheme.textTertiary)
                        .foregroundStyle(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(app.reclaimableBytes == 0 || isPerformingUninstall)
                }
            }
            .padding(14)
            .background(ThingsTheme.sidebar)
        }
    }

    // MARK: - Bundle Row
    private func bundleRow(_ app: InstalledAppInfo) -> some View {
        HStack(spacing: 10) {
            if app.isSystemProtected {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ThingsTheme.textTertiary)
                    .frame(width: 17, height: 17)
            } else {
                ThingsCheckbox(isChecked: app.isBundleSelected) {
                    uninstaller.toggleBundleSelection(appID: app.id)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(app.name).app (Application Bundle)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .lineLimit(1)

                    ThingsTag("Executable", color: ThingsTheme.infoIndigo)

                    if app.isSystemProtected {
                        ThingsTag("SIP Locked", color: ThingsTheme.textTertiary)
                    }
                }

                Text(app.bundleURL.path)
                    .font(.system(size: 10))
                    .foregroundStyle(ThingsTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ThingsTheme.textPrimary)
        }
        .padding(10)
        .background(ThingsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(app.isBundleSelected && !app.isSystemProtected ? ThingsTheme.accent.opacity(0.3) : ThingsTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Residue Row
    private func residueRow(app: InstalledAppInfo, item: AppResidueItem) -> some View {
        HStack(spacing: 10) {
            ThingsCheckbox(isChecked: item.isChecked) {
                uninstaller.toggleResidueItem(appID: app.id, residueID: item.id)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .lineLimit(1)

                    ThingsTag(item.categoryName, color: ThingsTheme.infoIndigo)
                }

                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10))
                    .foregroundStyle(ThingsTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10))
                    .foregroundStyle(ThingsTheme.textTertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Reveal file in Finder")

            Text(item.formattedSize)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ThingsTheme.textPrimary)
        }
        .padding(10)
        .background(ThingsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(item.isChecked ? ThingsTheme.accent.opacity(0.3) : ThingsTheme.border, lineWidth: 1)
        )
    }

    // MARK: - In-Window Confirmation Modal Card
    private func uninstallConfirmationCard(app: InstalledAppInfo) -> some View {
        let willTrashBundle = app.isBundleSelected && !app.isSystemProtected

        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ThingsTheme.vitalCrimson.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ThingsTheme.vitalCrimson)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(willTrashBundle ? "Completely Uninstall \(app.name)?" : "Clean Selected Residue for \(app.name)?")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ThingsTheme.textPrimary)
                    Text("Safe stage to macOS Trash • Restorable anytime")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showingUninstallConfirmation = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ThingsTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(isPerformingUninstall)
            }

            Divider().background(ThingsTheme.borderSubtle)

            // Content Summary
            Text("Crucial will safely move \(app.formattedReclaimableSize) into your macOS Trash:")
                .font(.system(size: 11.5))
                .foregroundStyle(ThingsTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                if willTrashBundle {
                    HStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ThingsTheme.accent)
                        Text("\(app.name).app (Application Bundle)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(ThingsTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(ThingsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if app.checkedResidueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ThingsTheme.infoIndigo)
                        Text("\(app.checkedResidueCount) support folders, caches & preferences")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(ThingsTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.checkedResidueBytes, countStyle: .file))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ThingsTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(ThingsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if app.isRunning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ThingsTheme.starOchre)
                    Text("\(app.name) is currently open in memory. Crucial will quit the app cleanly before moving files.")
                        .font(.system(size: 11))
                        .foregroundStyle(ThingsTheme.starOchre)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThingsTheme.starOchre.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider().background(ThingsTheme.borderSubtle)

            // Actions
            HStack {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showingUninstallConfirmation = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(ThingsTheme.card)
                        .foregroundStyle(ThingsTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(ThingsTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .disabled(isPerformingUninstall)

                Spacer()

                Button {
                    isPerformingUninstall = true
                    Task {
                        _ = await uninstaller.uninstallApp(app)
                        isPerformingUninstall = false
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showingUninstallConfirmation = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isPerformingUninstall {
                            ProgressView().scaleEffect(0.6)
                            Text("Moving to Trash...")
                                .font(.system(size: 12, weight: .bold))
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(willTrashBundle ? "Move to Trash" : "Clean Residue")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(ThingsTheme.vitalCrimson)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(isPerformingUninstall)
            }
        }
        .padding(20)
        .frame(width: 450)
        .background(ThingsTheme.cardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ThingsTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 10)
    }

    // MARK: - Drag and Drop Handler
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Attempt 1: loadObject as URL
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension == "app" {
                    DispatchQueue.main.async {
                        uninstaller.inspectCustomApp(url: url)
                    }
                }
            }
            return true
        }

        // Attempt 2: loadItem for type identifiers
        let types = ["public.file-url", UTType.fileURL.identifier, UTType.application.identifier]
        for type in types {
            if provider.hasItemConformingToTypeIdentifier(type) {
                provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                    var targetURL: URL?
                    if let url = item as? URL {
                        targetURL = url
                    } else if let data = item as? Data,
                              let str = String(data: data, encoding: .utf8),
                              let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        targetURL = url
                    }
                    if let url = targetURL, url.pathExtension == "app" {
                        DispatchQueue.main.async {
                            uninstaller.inspectCustomApp(url: url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
