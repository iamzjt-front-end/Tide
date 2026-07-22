import Foundation
import Testing
@testable import Tide

struct PomodoroStatisticsTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  @Test func emptyPeriodStillContainsEveryDate() {
    let now = date(2026, 7, 18, 12)
    let result = PomodoroStatistics.snapshot(
      sessions: [],
      period: .sevenDays,
      now: now,
      calendar: calendar
    )
    #expect(result.totalFocusSeconds == 0)
    #expect(result.completedCount == 0)
    #expect(result.daily.count == 7)
  }

  @Test func includesEarlyCompletionTimeAndCountsItAsCompleted() {
    let now = date(2026, 7, 18, 12)
    let completed = session(
      start: date(2026, 7, 17, 23, 50),
      end: date(2026, 7, 18, 0, 15),
      duration: 1_500,
      outcome: .completed,
      tag: "学习"
    )
    let completedEarly = session(
      start: date(2026, 7, 18, 9),
      end: date(2026, 7, 18, 9, 10),
      duration: 600,
      outcome: .completedEarly,
      tag: "工作"
    )
    let result = PomodoroStatistics.snapshot(
      sessions: [completed, completedEarly],
      period: .today,
      now: now,
      calendar: calendar
    )
    #expect(result.totalFocusSeconds == 2_100)
    #expect(result.completedCount == 2)
    #expect(result.earlyCompletedCount == 1)
    #expect(result.averageSeconds == 1_050)
    #expect(result.daily.first?.seconds == 2_100)
  }

  @Test func tagDistributionHasStableOrder() {
    let now = date(2026, 7, 18, 12)
    let records = [
      session(start: date(2026, 7, 18, 8), end: date(2026, 7, 18, 8, 25), duration: 1_500, outcome: .completed, tag: "工作"),
      session(start: date(2026, 7, 18, 9), end: date(2026, 7, 18, 9, 20), duration: 1_200, outcome: .completed, tag: "学习"),
      session(start: date(2026, 7, 18, 10), end: date(2026, 7, 18, 10, 10), duration: 600, outcome: .completed, tag: "工作"),
    ]
    let result = PomodoroStatistics.snapshot(
      sessions: records,
      period: .today,
      now: now,
      calendar: calendar
    )
    #expect(result.tagDistribution.map(\.name) == ["工作", "学习"])
    #expect(result.tagDistribution.first?.seconds == 2_100)
  }

  @Test func currentWeekAlwaysRunsFromMondayThroughSunday() {
    var sundayFirstCalendar = calendar
    sundayFirstCalendar.firstWeekday = 1
    let interval = PomodoroStatistics.currentWeekInterval(
      containing: date(2026, 7, 20, 12),
      calendar: sundayFirstCalendar
    )

    #expect(interval.start == date(2026, 7, 20))
    #expect(interval.end == date(2026, 7, 27))
  }

  @Test func monthChartAxisUsesDatesInsteadOfWeekdays() {
    let style = ClipoStatsRange.month.axisLabelStyle(bucket: .day)
    let label = ClipoStatisticsAxisLabelFormatter.text(
      for: date(2026, 7, 20),
      style: style,
      calendar: calendar
    )

    #expect(style == .dayOfMonth)
    #expect(label == "20日")
    #expect(ClipoStatsRange.week.axisLabelStyle(bucket: .day) == .weekday)
    #expect(ClipoStatsRange.year.axisLabelStyle(bucket: .month) == .month)
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(
      timeZone: calendar.timeZone,
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute
    ))!
  }

  private func session(
    start: Date,
    end: Date,
    duration: Int,
    outcome: SessionOutcome,
    tag: String
  ) -> FocusSession {
    FocusSession(
      runID: UUID(),
      startedAt: start,
      endedAt: end,
      durationSeconds: duration,
      plannedSeconds: 1_500,
      outcome: outcome,
      tagName: tag,
      tagColorHex: tag == "工作" ? "#FF6B6B" : "#4DABF7"
    )
  }
}
