//
//  NotificationManager.swift
//  Stan
//
//  Created by Michał Lisicki on 11/11/2025.
//

import Foundation
import UserNotifications

struct NotificationManager {
  static func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  static func pushNotification(isBreak: Bool) {
    requestAuthorization()

    let content = UNMutableNotificationContent()

    if !isBreak {
      content.title = "Work's done!"
      content.body = "Take a break!"
    } else {
      content.title = "Break's up!"
      content.body = "Get back to work!"
    }

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil)

    UNUserNotificationCenter.current().add(request)
  }
}
