import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
  let controller: PomodoroController
  let updateController: TideUpdateController
  let presentation = TidePresentationState()

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let statusBarImageRenderer = StatusBarImageRenderer()
  private let popover = NSPopover()
  private var refreshTask: Task<Void, Never>?
  private var lastStatusBarPresentation: StatusBarPresentation?
  private var checkForUpdatesMenuItem: NSMenuItem?

  private lazy var statusItemMenu: NSMenu = {
    let menu = NSMenu()
    menu.autoenablesItems = false

    let versionItem = NSMenuItem(
      title: "Tide \(Self.versionText)",
      action: nil,
      keyEquivalent: ""
    )
    versionItem.isEnabled = false
    menu.addItem(versionItem)
    menu.addItem(.separator())

    let updateItem = NSMenuItem(
      title: "检查更新…",
      action: #selector(checkForUpdates),
      keyEquivalent: ""
    )
    updateItem.target = self
    updateItem.image = NSImage(
      systemSymbolName: "arrow.triangle.2.circlepath",
      accessibilityDescription: nil
    )
    checkForUpdatesMenuItem = updateItem
    menu.addItem(updateItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "退出 Tide",
      action: #selector(quitApplication),
      keyEquivalent: "q"
    )
    quitItem.target = self
    quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
    menu.addItem(quitItem)
    return menu
  }()

  init(controller: PomodoroController, updateController: TideUpdateController) {
    self.controller = controller
    self.updateController = updateController
    super.init()
    configureStatusItem()
    configurePopover()
    startRefreshing()
  }

  deinit {
    refreshTask?.cancel()
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.target = self
    button.action = #selector(handleStatusItemClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleNone
    button.title = ""
    updateStatusItem()
  }

  private func configurePopover() {
    popover.behavior = .transient
    popover.animates = true
    popover.contentSize = NSSize(
      width: TidePopoverMetrics.width,
      height: TidePopoverMetrics.height(for: presentation.page)
    )
    let hostingController = NSHostingController(rootView: makeRootView())
    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    popover.contentViewController = hostingController
    updatePopoverAppearance()
  }

  private func makeRootView() -> TidePopoverRoot {
    TidePopoverRoot(
      controller: controller,
      presentation: presentation,
      updateController: updateController,
      onPreferredHeightChange: { [weak self] height in
        self?.setPopoverHeight(height)
      }
    )
  }

  private func setPopoverHeight(_ height: CGFloat) {
    guard abs(popover.contentSize.height - height) > 0.5 else { return }
    popover.contentSize = NSSize(width: TidePopoverMetrics.width, height: height)
  }

  @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    guard let event = NSApplication.shared.currentEvent else {
      togglePopover()
      return
    }

    if event.type == .rightMouseUp {
      checkForUpdatesMenuItem?.isEnabled = updateController.canCheckForUpdates
      NSMenu.popUpContextMenu(statusItemMenu, with: event, for: sender)
    } else {
      togglePopover()
    }
  }

  private func togglePopover() {
    if popover.isShown {
      closePopover()
    } else {
      showPopover()
    }
  }

  @objc private func checkForUpdates() {
    updateController.checkForUpdates()
  }

  @objc private func quitApplication() {
    NSApplication.shared.terminate(nil)
  }

  private func showPopover() {
    guard let button = statusItem.button else { return }
    presentation.prepareForPopoverPresentation()
    controller.reconcile()
    updatePopoverAppearance()
    setPopoverHeight(TidePopoverMetrics.height(for: presentation.page))
    NSApplication.shared.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    Task { @MainActor [weak self] in
      await Task.yield()
      guard let self, self.popover.isShown,
            let view = self.popover.contentViewController?.view,
            let window = view.window
      else { return }
      window.makeKey()
      window.makeFirstResponder(view)
      await self.controller.requestNotificationAuthorizationIfNeeded()
    }
  }

#if DEBUG
  func showPopoverForWalkthrough() {
    showPopover()
  }
#endif

  func showPopoverFromNotification() {
    if popover.isShown {
      guard let view = popover.contentViewController?.view else { return }
      view.window?.makeKey()
      return
    }
    showPopover()
  }

  private func closePopover() {
    popover.performClose(nil)
  }

  private func startRefreshing() {
    refreshTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        self.controller.reconcile()
        self.updatePopoverAppearance()
        self.updateStatusItem()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private func updatePopoverAppearance() {
    popover.appearance = switch controller.configuration.appearance {
    case .system: NSApplication.shared.effectiveAppearance
    case .light: NSAppearance(named: .aqua)
    case .dark: NSAppearance(named: .darkAqua)
    }
  }

  private func updateStatusItem() {
    guard let button = statusItem.button else { return }
    let next = StatusBarPresentation(
      symbolName: controller.menuBarSymbol,
      timeText: controller.menuBarTime,
      phaseTitle: controller.snapshot.phase.title,
      runStateTitle: controller.snapshot.runState.title
    )
    guard next != lastStatusBarPresentation else { return }

    if next.symbolName != lastStatusBarPresentation?.symbolName ||
       next.timeText != lastStatusBarPresentation?.timeText {
      button.image = statusBarImageRenderer.image(
        symbolName: next.symbolName,
        timeText: next.timeText
      )
      let targetLength = statusBarImageRenderer.canvasSize(for: next.timeText).width + 4
      if abs(statusItem.length - targetLength) > 0.5 {
        statusItem.length = targetLength
      }
    }

    button.toolTip = "Tide · \(next.phaseTitle) · \(next.runStateTitle)"
    button.setAccessibilityLabel("Tide 番茄钟")
    button.setAccessibilityValue("\(next.phaseTitle)，\(controller.formattedTime)，\(next.runStateTitle)")
    button.setAccessibilityHelp("打开或关闭 Tide")
    lastStatusBarPresentation = next
  }

  private static var versionText: String {
    let version = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String
    return "v\(version ?? "0.0.1")"
  }

}

private struct StatusBarPresentation: Equatable {
  var symbolName: String
  var timeText: String
  var phaseTitle: String
  var runStateTitle: String
}

@MainActor
private struct StatusBarImageRenderer {
  private let iconSide: CGFloat = 14
  private let itemSpacing: CGFloat = 4
  private let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)

  func canvasSize(for timeText: String) -> NSSize {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let timeWidth = ceil((timeText as NSString).size(withAttributes: attributes).width)
    return NSSize(width: iconSide + itemSpacing + timeWidth, height: 18)
  }

  func image(symbolName: String, timeText: String) -> NSImage {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.black,
    ]
    let textSize = (timeText as NSString).size(withAttributes: attributes)
    let canvasSize = canvasSize(for: timeText)
    let originX: CGFloat = 0
    let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
    let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)

    let result = NSImage(size: canvasSize, flipped: false) { rect in
      NSGraphicsContext.current?.imageInterpolation = .high
      let iconRect = NSRect(
        x: originX,
        y: floor((rect.height - iconSide) / 2),
        width: iconSide,
        height: iconSide
      )
      symbol?.draw(
        in: iconRect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: nil
      )
      let textRect = NSRect(
        x: originX + iconSide + itemSpacing,
        y: floor((rect.height - textSize.height) / 2),
        width: ceil(textSize.width),
        height: ceil(textSize.height)
      )
      (timeText as NSString).draw(in: textRect, withAttributes: attributes)
      return true
    }
    result.isTemplate = true
    return result
  }
}
