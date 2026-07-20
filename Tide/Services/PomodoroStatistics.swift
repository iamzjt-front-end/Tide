import Foundation

enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
  case today
  case sevenDays
  case thirtyDays

  var id: Self { self }

  var title: String {
    switch self {
    case .today: "今天"
    case .sevenDays: "近 7 天"
    case .thirtyDays: "近 30 天"
    }
  }

  var dayCount: Int {
    switch self {
    case .today: 1
    case .sevenDays: 7
    case .thirtyDays: 30
    }
  }
}

struct FocusDayPoint: Identifiable, Equatable, Sendable {
  var day: Date
  var seconds: Int
  var completedCount: Int
  var earlyCompletedCount: Int

  var id: Date { day }
}

struct FocusDistributionItem: Identifiable, Equatable, Sendable {
  var name: String
  var colorHex: String
  var seconds: Int

  var id: String { "\(name)|\(colorHex)" }
}

struct PomodoroStatisticsSnapshot: Equatable, Sendable {
  var totalFocusSeconds: Int
  var completedCount: Int
  var earlyCompletedCount: Int
  var averageSeconds: Int
  var daily: [FocusDayPoint]
  var tagDistribution: [FocusDistributionItem]

  static let empty = PomodoroStatisticsSnapshot(
    totalFocusSeconds: 0,
    completedCount: 0,
    earlyCompletedCount: 0,
    averageSeconds: 0,
    daily: [],
    tagDistribution: []
  )
}

enum PomodoroStatistics {
  enum Bucket: Sendable {
    case day
    case month
  }

  static func snapshot(
    sessions: [FocusSession],
    period: StatisticsPeriod,
    now: Date = .now,
    calendar: Calendar = .current
  ) -> PomodoroStatisticsSnapshot {
    let today = calendar.startOfDay(for: now)
    let start = calendar.date(byAdding: .day, value: -(period.dayCount - 1), to: today) ?? today
    let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
    let selected = sessions.filter { $0.endedAt >= start && $0.endedAt < end }
    let completed = selected
    let earlyCompleted = selected.filter { $0.outcome.isEarlyCompletion }
    let total = completed.reduce(0) { $0 + max(0, $1.durationSeconds) }

    let daily = (0..<period.dayCount).compactMap { offset -> FocusDayPoint? in
      guard let day = calendar.date(byAdding: .day, value: offset, to: start),
            let next = calendar.date(byAdding: .day, value: 1, to: day)
      else { return nil }
      let records = selected.filter { $0.endedAt >= day && $0.endedAt < next }
      return FocusDayPoint(
        day: day,
        seconds: records.reduce(0) { $0 + max(0, $1.durationSeconds) },
        completedCount: records.count,
        earlyCompletedCount: records.filter { $0.outcome.isEarlyCompletion }.count
      )
    }

    let grouped = Dictionary(grouping: completed) { session in
      "\(session.tagName ?? "未分类")|\(session.tagColorHex ?? "#868E96")"
    }
    let distribution = grouped.map { key, records -> FocusDistributionItem in
      let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
      return FocusDistributionItem(
        name: parts.first ?? "未分类",
        colorHex: parts.count > 1 ? parts[1] : "#868E96",
        seconds: records.reduce(0) { $0 + $1.durationSeconds }
      )
    }
    .sorted { lhs, rhs in
      if lhs.seconds == rhs.seconds { return lhs.name < rhs.name }
      return lhs.seconds > rhs.seconds
    }

    return PomodoroStatisticsSnapshot(
      totalFocusSeconds: total,
      completedCount: completed.count,
      earlyCompletedCount: earlyCompleted.count,
      averageSeconds: completed.isEmpty ? 0 : total / completed.count,
      daily: daily,
      tagDistribution: distribution
    )
  }

  static func snapshot(
    sessions: [FocusSession],
    from start: Date,
    to end: Date,
    bucket: Bucket,
    calendar: Calendar = .current
  ) -> PomodoroStatisticsSnapshot {
    guard start < end else { return .empty }
    let selected = sessions.filter { $0.endedAt >= start && $0.endedAt < end }
    let completed = selected
    let earlyCompleted = selected.filter { $0.outcome.isEarlyCompletion }
    let total = completed.reduce(0) { $0 + max(0, $1.durationSeconds) }

    var intervals: [DateInterval] = []
    var cursor = bucket == .day
      ? calendar.startOfDay(for: start)
      : (calendar.dateInterval(of: .month, for: start)?.start ?? start)
    var safety = 0
    while cursor < end, safety < 4_000 {
      let component: Calendar.Component = bucket == .day ? .day : .month
      guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
      intervals.append(DateInterval(start: cursor, end: min(next, end)))
      cursor = next
      safety += 1
    }

    let points = intervals.map { interval in
      let records = selected.filter { $0.endedAt >= interval.start && $0.endedAt < interval.end }
      return FocusDayPoint(
        day: interval.start,
        seconds: records.reduce(0) { $0 + max(0, $1.durationSeconds) },
        completedCount: records.count,
        earlyCompletedCount: records.filter { $0.outcome.isEarlyCompletion }.count
      )
    }

    let grouped = Dictionary(grouping: completed) { session in
      "\(session.tagName ?? "未分类")|\(session.tagColorHex ?? "#868E96")"
    }
    let distribution = grouped.map { key, records -> FocusDistributionItem in
      let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
      return FocusDistributionItem(
        name: parts.first ?? "未分类",
        colorHex: parts.count > 1 ? parts[1] : "#868E96",
        seconds: records.reduce(0) { $0 + $1.durationSeconds }
      )
    }
    .sorted { lhs, rhs in
      if lhs.seconds == rhs.seconds { return lhs.name < rhs.name }
      return lhs.seconds > rhs.seconds
    }

    return PomodoroStatisticsSnapshot(
      totalFocusSeconds: total,
      completedCount: completed.count,
      earlyCompletedCount: earlyCompleted.count,
      averageSeconds: completed.isEmpty ? 0 : total / completed.count,
      daily: points,
      tagDistribution: distribution
    )
  }
}
