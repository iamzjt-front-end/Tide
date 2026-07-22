import AppKit
import Foundation
import UserNotifications

enum PomodoroNotificationAuthorization: Equatable, Sendable {
  case unknown
  case notDetermined
  case denied
  case authorized

  var allowsNotifications: Bool { self == .authorized }

  var statusText: String {
    switch self {
    case .unknown: "正在检查系统权限…"
    case .notDetermined: "尚未请求系统通知权限"
    case .denied: "系统通知权限未开启"
    case .authorized: "系统通知权限已允许"
    }
  }
}

enum PomodoroNotificationDelivery: Equatable, Sendable {
  case gentleReminder
  case completion
}

enum PomodoroNotificationScheduleResult: Equatable, Sendable {
  case scheduled
  case failed(String)
}

@MainActor
protocol PomodoroNotifying: AnyObject {
  func authorizationStatus() async -> PomodoroNotificationAuthorization
  func requestAuthorization() async -> Bool
  func schedule(
    id: String,
    title: String,
    body: String,
    at date: Date,
    delivery: PomodoroNotificationDelivery
  ) async -> PomodoroNotificationScheduleResult
  func cancel(id: String)
}

@MainActor
protocol PomodoroSounding: AnyObject {
  func playCompletion()
}

@MainActor
final class SystemPomodoroSoundPlayer: PomodoroSounding {
  func playCompletion() {
    NSSound(named: "Pop")?.play()
  }
}

@MainActor
final class SilentPomodoroSoundPlayer: PomodoroSounding {
  private(set) var playCount = 0

  func playCompletion() {
    playCount += 1
  }
}

@MainActor
final class SystemPomodoroNotifier: PomodoroNotifying {
  private let center = UNUserNotificationCenter.current()

  func authorizationStatus() async -> PomodoroNotificationAuthorization {
    let settings = await center.notificationSettings()
    return switch settings.authorizationStatus {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized, .provisional, .ephemeral: .authorized
    @unknown default: .denied
    }
  }

  func requestAuthorization() async -> Bool {
    do {
      _ = try await center.requestAuthorization(options: [.alert, .sound])
      return (await authorizationStatus()).allowsNotifications
    } catch {
      return false
    }
  }

  func schedule(
    id: String,
    title: String,
    body: String,
    at date: Date,
    delivery: PomodoroNotificationDelivery
  ) async -> PomodoroNotificationScheduleResult {
    center.removePendingNotificationRequests(withIdentifiers: [id])
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    switch delivery {
    case .gentleReminder:
      content.sound = nil
      content.interruptionLevel = .active
    case .completion:
      content.sound = .default
      content.interruptionLevel = .timeSensitive
    }
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: max(1, date.timeIntervalSinceNow),
      repeats: false
    )
    do {
      try await center.add(UNNotificationRequest(
        identifier: id,
        content: content,
        trigger: trigger
      ))
      return .scheduled
    } catch {
      return .failed(error.localizedDescription)
    }
  }

  func cancel(id: String) {
    center.removePendingNotificationRequests(withIdentifiers: [id])
  }
}

@MainActor
final class SilentPomodoroNotifier: PomodoroNotifying {
  struct Scheduled: Equatable {
    var id: String
    var title: String
    var body: String
    var date: Date
    var delivery: PomodoroNotificationDelivery
  }

  var authorizationResult = true
  var authorizationStatusValue: PomodoroNotificationAuthorization = .authorized
  var scheduleResult: PomodoroNotificationScheduleResult = .scheduled
  private(set) var authorizationRequestCount = 0
  private(set) var scheduled: [Scheduled] = []
  private(set) var cancelledIDs: [String] = []

  func authorizationStatus() async -> PomodoroNotificationAuthorization {
    authorizationStatusValue
  }

  func requestAuthorization() async -> Bool {
    authorizationRequestCount += 1
    authorizationStatusValue = authorizationResult ? .authorized : .denied
    return authorizationResult
  }

  func schedule(
    id: String,
    title: String,
    body: String,
    at date: Date,
    delivery: PomodoroNotificationDelivery
  ) async -> PomodoroNotificationScheduleResult {
    guard scheduleResult == .scheduled else { return scheduleResult }
    scheduled.removeAll { $0.id == id }
    scheduled.append(Scheduled(
      id: id,
      title: title,
      body: body,
      date: date,
      delivery: delivery
    ))
    return .scheduled
  }

  func cancel(id: String) {
    scheduled.removeAll { $0.id == id }
    cancelledIDs.append(id)
  }
}
