import AppKit
import SwiftUI
import UserNotifications

@main
struct TideApp: App {
  @NSApplicationDelegateAdaptor(TideAppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class TideAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private var statusBarController: StatusBarController?
  private var observers: [NSObjectProtocol] = []
#if DEBUG
  private var walkthroughWindow: NSWindow?
#endif

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    UNUserNotificationCenter.current().delegate = self
    let controller = PomodoroController()
    statusBarController = StatusBarController(controller: controller)
    Task { @MainActor [weak controller] in
      await Task.yield()
      await controller?.requestNotificationAuthorizationIfNeeded()
    }

#if DEBUG
    if ProcessInfo.processInfo.environment["TIDE_UI_OPEN_POPOVER"] == "1" {
      Task { @MainActor [weak self] in
        await Task.yield()
        self?.statusBarController?.showPopoverForWalkthrough()
      }
    }
    if ProcessInfo.processInfo.environment["TIDE_UI_WALKTHROUGH"] == "1" {
      showWalkthroughWindow()
    }
#endif

    let center = NotificationCenter.default
    observers.append(center.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak controller] _ in
      Task { @MainActor in controller?.reconcile() }
    })
    observers.append(center.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak controller] _ in
      Task { @MainActor in controller?.reconcile() }
    })
  }

  func applicationWillTerminate(_ notification: Notification) {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    .banner
  }

#if DEBUG
  private func showWalkthroughWindow() {
    let sampleArchive = ProcessInfo.processInfo.environment["TIDE_UI_SAMPLE_DATA"] == "1"
      ? makeSampleArchive()
      : nil
    let controller = PomodoroController(
      persistence: InMemoryPomodoroPersistence(archive: sampleArchive),
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer()
    )
    controller.startMonitoring()
    let presentation = TidePresentationState()
    let window = NSWindow(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: TidePopoverMetrics.width,
        height: TidePopoverMetrics.height(for: .timer)
      ),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Tide UI Walkthrough"
    window.isReleasedWhenClosed = false
    window.center()
    window.contentView = NSHostingView(
      rootView: TidePopoverRoot(
        controller: controller,
        presentation: presentation
      )
    )
    walkthroughWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  private func makeSampleArchive(now: Date = .now) -> PomodoroArchive {
    var archive = PomodoroArchive.fresh(now: now)
    let study = FocusTag(name: "学习", colorHex: "#4DABF7")
    let writing = FocusTag(name: "写作", colorHex: "#F783AC")
    archive.focusTags = [study, writing]
    archive.configuration.selectedTagID = study.id
    archive.sessions = (0..<12).map { offset in
      let endedAt = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
      let tag = offset.isMultiple(of: 2) ? study : writing
      return FocusSession(
        runID: UUID(),
        startedAt: endedAt.addingTimeInterval(-Double(offset.isMultiple(of: 3) ? 3_000 : 1_500)),
        endedAt: endedAt,
        durationSeconds: offset.isMultiple(of: 3) ? 3_000 : 1_500,
        plannedSeconds: 1_500,
        outcome: offset == 4 ? .completedEarly : .completed,
        tagID: tag.id,
        tagName: tag.name,
        tagColorHex: tag.colorHex
      )
    }
    return archive
  }
#endif
}
