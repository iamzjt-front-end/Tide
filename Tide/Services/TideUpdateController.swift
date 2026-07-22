import Foundation
import Observation
import Sparkle
import UserNotifications

@MainActor
@Observable
final class TideUpdateController {
  static let updateNotificationIdentifier = "Tide.UpdateAvailable"

  private(set) var canCheckForUpdates = false

  @ObservationIgnored private let userDriverDelegate = TideUpdateUserDriverDelegate()
  @ObservationIgnored private var sparkleController: SPUStandardUpdaterController?
  @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

  init(startingUpdater: Bool = true) {
    guard startingUpdater else { return }

    let controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: userDriverDelegate
    )
    sparkleController = controller
    canCheckForUpdates = controller.updater.canCheckForUpdates
    canCheckObservation = controller.updater.observe(
      \.canCheckForUpdates,
      options: [.initial, .new]
    ) { [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.canCheckForUpdates = self.sparkleController?.updater.canCheckForUpdates ?? false
      }
    }
  }

  func checkForUpdates() {
    sparkleController?.checkForUpdates(nil)
  }

  func handleNotification(identifier: String) -> Bool {
    guard identifier == Self.updateNotificationIdentifier else {
      return false
    }
    checkForUpdates()
    return true
  }
}

@MainActor
private final class TideUpdateUserDriverDelegate: NSObject, @MainActor SPUStandardUserDriverDelegate {
  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool,
    forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    guard handleShowingUpdate, !state.userInitiated else { return }

    let content = UNMutableNotificationContent()
    content.title = "Tide 有新版本"
    content.body = "版本 \(update.displayVersionString) 已可安装，点击查看更新。"
    let request = UNNotificationRequest(
      identifier: TideUpdateController.updateNotificationIdentifier,
      content: content,
      trigger: nil
    )
    Task {
      try? await UNUserNotificationCenter.current().add(request)
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    removeUpdateNotification()
  }

  func standardUserDriverWillFinishUpdateSession() {
    removeUpdateNotification()
  }

  private func removeUpdateNotification() {
    let center = UNUserNotificationCenter.current()
    let identifiers = [TideUpdateController.updateNotificationIdentifier]
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }
}
