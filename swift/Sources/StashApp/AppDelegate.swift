import AppKit
import Combine
import StashCore
import StashUI
import SwiftUI

/// The application delegate that wires every part together.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    // Core
    private var database: SQLiteConnection!
    private var repository: Repository!
    private var syncService: ICloudSync?

    // State
    private let settings = SettingsStore()
    private let toast = ToastCenter()
    private let iconStore = AppIconStore()
    private var panelModel: PanelViewModel!
    private var widgetModel: WidgetViewModel!

    // Windows
    private var panelController: PanelWindowController!
    private var settingsController: SettingsWindowController!
    private var widgetController: WidgetWindowController!
    private var trayController: TrayController!

    // Services
    private let hotKeys = GlobalHotKeyManager()
    private var clipboardMonitor: ClipboardMonitor!
    private var queueManager: SequenceQueueManager!
    private var updateController: UpdateController!
    private var autoCleanupTimer: Timer?
    private var autoUpdateTimer: Timer?
    private var appearanceSubscription: AnyCancellable?

    private var theme: StashTheme {
        StashTheme(resolved: settings.resolvedTheme, accentHex: settings.accentColor)
    }

    // MARK: - Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppPaths.ensureDirectories()

        do {
            let existingDatabase = FileManager.default.fileExists(atPath: AppPaths.databaseURL.path)
            database = try SQLiteConnection(path: AppPaths.databaseURL.path)
            if existingDatabase {
                let backup = AppPaths.supportDirectory.appendingPathComponent("backups/pre-native-repair.sqlite3")
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
                    do { try database.backup(to: backup) }
                    catch { try? FileManager.default.removeItem(at: backup); throw error }
                }
            }
            try Schema.createTables(in: database)
            repository = Repository(db: database)
        } catch {
            NSLog("[Stash] failed to open the database: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "Stash"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        Localization.shared.setLanguage(settings.resolvedLanguage())

        // The layout mode of the previous build is taken over.
        if let storedMode = LayoutModeStore.load() {
            settings.layoutMode = storedMode
        }
        NSApp.mainMenu = MainMenuBuilder.build(language: Localization.shared.language)

        panelModel = PanelViewModel(repository: repository)
        widgetModel = WidgetViewModel(repository: repository)
        queueManager = SequenceQueueManager(repository: repository)
        updateController = UpdateController(currentVersion: Self.versionString)

        panelController = PanelWindowController(settings: settings)
        panelController.onVisibilityChanged = { [weak self] visible in
            self?.panelModel.isVisible = visible
        }
        settingsController = SettingsWindowController()
        widgetController = WidgetWindowController()
        trayController = TrayController(windowController: panelController, repository: repository)

        configureModel()
        configureWindows()
        configureTray()
        configureMonitor()
        configureNotifications()
        registerShortcuts()

        trayController.create()
        clipboardMonitor.start()

        if settings.iCloudSync {
            startSync()
        }

        startAutoCleanup()
        startAutoUpdate()

        if settings.hasCompletedOnboarding {
            panelController.show()
        } else {
            showOnboardingInPanel()
        }

        // The bundle declares `LSUIElement`, so the app already runs as a
        // menu bar utility. Changing the policy here would deactivate the
        // app right after the panel was shown.
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.show()
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if updateController?.phase == .downloaded {
            updateController.install()
            return .terminateCancel
        }
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregisterAll()
        clipboardMonitor?.stop()
        syncService?.stop()
        database?.close()
    }

    // MARK: - Configuration

    private func configureModel() {
        panelModel.onPaste = { [weak self] item in
            self?.paste(item)
        }
        panelModel.onHide = { [weak self] in
            self?.panelController.hide()
        }
        panelModel.onFilterChanged = { [weak self] in
            self?.syncWidgetFilter()
        }

        widgetModel.onPaste = { [weak self] item in
            self?.paste(item, fromWidget: true)
        }
        widgetModel.onClose = { [weak self] in
            self?.widgetController.hide()
        }
        widgetModel.onPinnedChanged = { [weak self] pinned in
            self?.widgetController.isPinned = pinned
        }

        queueManager.onUpdated = { [weak self] count in
            guard let self else { return }
            if count > 0 {
                self.toast.show(L10n.t("queue.added", ["count": String(count)]))
            }
        }
        queueManager.onPasted = { [weak self] index, total in
            self?.toast.show(L10n.t("queue.pasted", ["index": String(index), "total": String(total)]))
        }
        queueManager.onBatchPasted = { [weak self] count in
            self?.toast.show(L10n.t("queue.batchPasted", ["count": String(count)]))
        }
        queueManager.onFinished = { [weak self] in
            self?.toast.show(L10n.t("queue.cleared"))
            self?.panelModel.clearQueue()
        }
        queueManager.setBatchSeparator(settings.batchPasteSeparator)
        widgetModel.setFollowFilter(settings.widgetFollowFilter)
        syncWidgetFilter()
        panelModel.onDataChanged = { [weak self] in
            self?.widgetModel.load()
            self?.trayController.refresh()
        }
    }

    private func configureWindows() {
        panelController.setContent(panelRootView())
        settingsController.onClosed = { [weak self] in
            self?.panelModel.loadItems()
            self?.panelModel.loadTags()
            self?.widgetModel.load()
            self?.trayController.refresh()
            self?.panelController.show()
        }
        widgetController.setContent(widgetRootView())
        refreshAppearance()
        appearanceSubscription = settings.$resolvedTheme
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
            }
    }

    private func configureTray() {
        trayController.setLanguage(Localization.shared.language)
        trayController.setQuickPastePrefix(settings.widgetQuickPastePrefix)
        trayController.varLaunchAtLogin = LaunchAtLogin.isEnabled
        trayController.onLaunchAtLoginChanged = { [weak self] enabled in
            LaunchAtLogin.setEnabled(enabled)
            self?.settings.launchAtLogin = enabled
        }
        trayController.onPaste = { [weak self] item in self?.paste(item, fromWidget: true) }
        trayController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func configureMonitor() {
        let monitor = ClipboardMonitor(repository: repository)
        monitor.onNewItemHandler = { [weak self] item in
            DispatchQueue.main.async {
                guard let self else { return }
                self.panelModel.addItem(item)
                self.widgetModel.load()
                self.trayController.refresh()
            }
        }
        clipboardMonitor = monitor
    }

    private func configureNotifications() {
        // The application and the tray menu follow the selected language.
        NotificationCenter.default.addObserver(
            forName: Localization.languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                NSApp.mainMenu = MainMenuBuilder.build(language: Localization.shared.language)
                self.trayController.setLanguage(Localization.shared.language)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .stashQueueAdd,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let ids = notification.object as? [String] else { return }
            Task { @MainActor in self?.queueManager.addMultiple(ids: ids) }
        }

        NotificationCenter.default.addObserver(
            forName: .stashQueueClear,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.queueManager.clear() }
        }

        NotificationCenter.default.addObserver(
            forName: .stashSyncNow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncService?.syncNow() }
        }

        NotificationCenter.default.addObserver(
            forName: .stashBatchSeparatorChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let separator = notification.object as? String else { return }
            Task { @MainActor in self?.queueManager.setBatchSeparator(separator) }
        }

        NotificationCenter.default.addObserver(
            forName: .stashWidgetFollowFilterChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let value = notification.object as? Bool else { return }
            Task { @MainActor in
                self?.widgetModel.setFollowFilter(value)
                self?.widgetModel.load()
            }
        }

        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.settings.refreshResolvedTheme()
                self?.refreshAppearance()
            }
        }
    }

    // MARK: - Shortcuts

    private func registerShortcuts() {
        hotKeys.unregisterAll()

        registerHotKey(settings.customShortcut, "panel") { [weak self] in
            self?.panelController.show()
        }
        registerHotKey(settings.sequencePasteShortcut, "sequence") { [weak self] in
            guard let self, self.ensurePastePermission() else { return }
            self.queueManager.pasteNext()
        }
        registerHotKey(settings.batchPasteShortcut, "batch") { [weak self] in
            guard let self, self.ensurePastePermission() else { return }
            self.queueManager.pasteAll()
        }
        registerHotKey(settings.cycleLayoutShortcut, "layout") { [weak self] in
            self?.cycleLayout()
        }
        registerHotKey(settings.widgetToggleShortcut, "widget") { [weak self] in
            self?.widgetController.toggle()
            self?.widgetModel.load()
        }
        for index in 1...5 {
            registerHotKey("\(settings.widgetQuickPastePrefix)+\(index)", "quickPaste\(index)") { [weak self] in
                self?.quickPaste(index: index - 1)
            }
        }
    }

    /// Registers a global shortcut and logs failures.
    private func registerHotKey(_ accelerator: String, _ identifier: String, _ action: @escaping () -> Void) {
        if !hotKeys.register(accelerator: accelerator, identifier: identifier, handler: action) {
            toast.show(L10n.t("toast.shortcutUnavailable", ["shortcut": Shortcut.display(accelerator)]))
            NSLog("[Stash] could not register the global shortcut %@ (%@)", accelerator, identifier)
        }
    }

    private func cycleLayout() {
        let next = settings.layoutMode.next()
        settings.layoutMode = next
        LayoutModeStore.save(next)
        panelController.applyLayout()
        NotificationCenter.default.post(name: .stashLayoutModeChanged, object: next)
    }

    private func quickPaste(index: Int) {
        widgetModel.load()
        let items = widgetModel.items
        guard
              items.indices.contains(index)
        else { return }
        let item = items[index]
        paste(item, fromWidget: true)
    }

    // MARK: - Actions

    private func paste(_ item: ClipboardItem, fromWidget: Bool = false) {
        guard ensurePastePermission() else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let previousApp = frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier
            ? frontmost?.bundleIdentifier : panelController.previousApp

        guard PasteService.shared.write(content: item.content, contentType: item.contentType) else { return }
        if !fromWidget {
            panelController.hide()
        } else if !widgetModel.isPinned {
            // An unpinned widget hides itself after a paste.
            widgetController.hide()
        }
        try? repository.incrementUseCount(item.id)
        panelModel.hasPendingReload = true
        widgetModel.load()
        trayController.refresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            if let previousApp {
                PasteService.shared.activate(bundleId: previousApp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                PasteService.shared.simulatePaste(into: previousApp)
            }
        }
    }

    private func ensurePastePermission() -> Bool {
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.prompt()
            toast.show(L10n.t("toast.accessibilityRequired"))
            return false
        }
        return true
    }

    private func syncWidgetFilter() {
        widgetModel.setFilter(WidgetViewModel.WidgetFilter(
            contentType: panelModel.filterType,
            leftFilter: panelModel.leftFilter,
            sourceApp: panelModel.sourceAppFilter,
            sortBy: panelModel.sortBy
        ))
        if settings.widgetFollowFilter {
            widgetModel.load()
        }
    }

    private func startSync() {
        if syncService == nil {
            syncService = ICloudSync(repository: repository)
            syncService?.onImported = { [weak self] in
                self?.panelModel.loadItems()
                self?.panelModel.loadTags()
                self?.widgetModel.load()
                self?.trayController.refresh()
            }
        }
        syncService?.start()
    }

    private func stopSync() {
        syncService?.stop()
    }

    /// Removes the oldest items when the history grows beyond the configured
    /// limit. Runs every ten minutes, like the previous implementation.
    /// Checks for new releases once an hour and shows the system dialogs the
    /// previous build showed.
    private func startAutoUpdate() {
        // Development builds never talk to the update server.
        guard !AppPaths.isIsolated, Bundle.main.bundlePath.hasSuffix(".app"),
              Bundle.main.bundleIdentifier == "com.zpaste.app"
        else { return }

        updateController.onUpdateAvailable = { [weak self] version in
            self?.showUpdateAvailableDialog(version: version)
        }
        updateController.onUpdateDownloaded = { [weak self] in
            self?.showUpdateDownloadedDialog()
        }

        updateController.check()
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateController.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoUpdateTimer = timer
    }

    /// Asks the user whether the new release should be downloaded now.
    private func showUpdateAvailableDialog(version: String) {
        let alert = NSAlert()
        alert.messageText = L10n.t("updater.dialog.title")
        alert.informativeText = L10n.t("updater.dialog.message", ["version": version])
        alert.addButton(withTitle: L10n.t("updater.dialog.update"))
        alert.addButton(withTitle: L10n.t("updater.dialog.later"))
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            updateController.download()
        }
    }

    /// Asks the user whether the app should restart into the new release.
    private func showUpdateDownloadedDialog() {
        let alert = NSAlert()
        alert.messageText = L10n.t("updater.dialog.downloadedTitle")
        alert.informativeText = L10n.t("updater.dialog.downloadedMessage")
        alert.addButton(withTitle: L10n.t("updater.dialog.restartNow"))
        alert.addButton(withTitle: L10n.t("updater.dialog.later"))
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            updateController.install()
        }
    }

    private func startAutoCleanup() {
        let timer = Timer(timeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
            guard let self else { return }
            let maxItems = self.settings.maxItems
            try? self.repository.autoCleanup(maxItems: maxItems)
            try? self.repository.cleanupByRetention(days: self.settings.historyRetention)
            self.panelModel.loadItems()
            self.widgetModel.load()
            self.trayController.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoCleanupTimer = timer
    }

    // MARK: - Views

    private func panelRootView() -> some View {
        Group {
            if settings.hasCompletedOnboarding {
                PanelView(
                    model: panelModel,
                    settings: settings,
                    toast: toast,
                    iconStore: iconStore,
                    onOpenSettings: { [weak self] in
                        self?.openSettings()
                    },
                    onOpenOnboarding: { [weak self] in
                        self?.openOnboarding()
                    },
                    onLayoutModeChanged: { [weak self] mode in
                        LayoutModeStore.save(mode)
                        self?.panelController.applyLayout()
                    },
                    onHide: { [weak self] in
                        self?.panelController.hide()
                    }
                )
            } else {
                OnboardingView(
                    settings: settings,
                    isRevisit: false,
                    onComplete: { [weak self] in
                        self?.completeOnboarding()
                    },
                    onFinished: { [weak self] value in
                        self?.applySyncChoice(value)
                    }
                )
            }
        }
        .frame(minWidth: 0, minHeight: 0)
    }

    private func settingsRootView() -> some View {
        SettingsView(
            settings: settings,
            repository: repository,
            version: Self.versionString,
            updater: updateController,
            toast: toast,
            onClose: { [weak self] in
                self?.settingsController.close()
            },
            onLaunchAtLoginChanged: { enabled in
                LaunchAtLogin.setEnabled(enabled)
            },
            onSyncChanged: { [weak self] enabled in
                if enabled { self?.startSync() } else { self?.stopSync() }
            },
            onShortcutsChanged: { [weak self] in
                self?.registerShortcuts()
            },
            onLayoutModeChanged: { [weak self] mode in
                LayoutModeStore.save(mode)
                self?.panelController.applyLayout()
            },
            onWidgetChanged: { [weak self] in
                self?.registerShortcuts()
                self?.trayController.setQuickPastePrefix(self?.settings.widgetQuickPastePrefix ?? "Alt")
            },
            onClearAll: { [weak self] in
                self?.panelModel.clearAll()
            }
        )
    }

    private func widgetRootView() -> some View {
        WidgetView(model: widgetModel, settings: settings)
    }

    // MARK: - Flow

    private func showOnboardingInPanel() {
        panelController.show()
    }

    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        panelController.show()
    }

    /// Applies the iCloud choice of the onboarding.
    private func applySyncChoice(_ enabled: Bool) {
        settings.iCloudSync = enabled
        if enabled { startSync() } else { stopSync() }
    }

    private func openSettings() {
        settingsController.setContent(settingsRootView())
        settingsController.open(.settings)
    }

    private func openOnboarding() {
        settingsController.setContent(
            OnboardingView(
                settings: settings,
                isRevisit: true,
                onComplete: { [weak self] in
                    self?.settingsController.close()
                }
            )
        )
        settingsController.open(.onboarding)
    }

    private func refreshAppearance() {
        NSApp.appearance = NSAppearance(named: settings.resolvedTheme == .dark ? .darkAqua : .aqua)
        panelController.updateTheme(theme)
        settingsController.updateAppearance(settings.resolvedTheme)
    }

    static var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

extension Array {
    /// Returns the element at the given index when it exists.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
