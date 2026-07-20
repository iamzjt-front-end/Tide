import Charts
import SwiftUI

private enum ClipoStatsRange: String, CaseIterable, Identifiable {
  case day
  case week
  case month
  case year
  case all
  case custom

  var id: Self { self }

  var title: String {
    switch self {
    case .day: "日"
    case .week: "周"
    case .month: "月"
    case .year: "年"
    case .all: "全部"
    case .custom: "自定义"
    }
  }

  var summaryTitle: String {
    switch self {
    case .day: "今日专注"
    case .week: "本周专注"
    case .month: "本月专注"
    case .year: "本年专注"
    case .all: "全部专注"
    case .custom: "范围内专注"
    }
  }
}

struct ClipoStatisticsPage: View {
  var controller: PomodoroController

  @State private var range: ClipoStatsRange = .week
  @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
  @State private var customEnd = Date.now

  private var interval: DateInterval { selectedInterval() }

  private var bucket: PomodoroStatistics.Bucket {
    let days = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
    return range == .year || range == .all || days > 90 ? .month : .day
  }

  private var stats: PomodoroStatisticsSnapshot {
    PomodoroStatistics.snapshot(
      sessions: controller.sessions,
      from: interval.start,
      to: interval.end,
      bucket: bucket
    )
  }

  var body: some View {
    VStack(spacing: 13) {
      VStack(spacing: 6) {
        rangePicker

        if range == .custom {
          customRangePicker
        }

        Text(dateRangeLabel)
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .contentTransition(.numericText())
          .accessibilityLabel("统计日期范围，\(dateRangeLabel)")
      }
      .padding(.top, 9)

      GlassCard {
        HStack(alignment: .center, spacing: 14) {
          VStack(alignment: .leading, spacing: 5) {
            Text(range.summaryTitle)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
            Text(compactDuration(stats.totalFocusSeconds))
              .font(.system(size: 31, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.primary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Divider()

          statisticNumber(
            title: "按计划",
            value: max(0, stats.completedCount - stats.earlyCompletedCount),
            color: .accentColor
          )
          statisticNumber(
            title: "提前完成",
            value: stats.earlyCompletedCount,
            color: Color(hex: "#FFB454")
          )
        }
      }

      GlassCard {
        VStack(alignment: .leading, spacing: 10) {
          Text(range.summaryTitle)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
          ZStack {
            focusChart
            if stats.daily.allSatisfy({ $0.seconds == 0 }) {
              Text("暂无完成记录")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            }
          }
        }
      }

      GlassCard {
        VStack(alignment: .leading, spacing: 11) {
          Text("专注时间分布")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
          if stats.tagDistribution.isEmpty {
            Text("暂无专注记录")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
              .frame(maxWidth: .infinity, minHeight: 70)
          } else {
            HStack(spacing: 16) {
              distributionChart
              VStack(spacing: 7) {
                ForEach(stats.tagDistribution.prefix(4)) { item in
                  HStack(spacing: 6) {
                    Circle().fill(Color(hex: item.colorHex)).frame(width: 7, height: 7)
                    Text(item.name)
                      .font(.system(size: 10, weight: .medium))
                      .lineLimit(1)
                    Spacer()
                    Text(distributionLabel(item.seconds))
                      .font(.system(size: 9, weight: .semibold, design: .rounded))
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
        }
      }
    }
    .padding(.horizontal, 46)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var rangePicker: some View {
    HStack(spacing: 5) {
      ForEach(ClipoStatsRange.allCases) { item in
        let selected = item == range
        Button {
          range = item
        } label: {
          Text(item.title)
            .font(.system(size: 11, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.62))
            .padding(.horizontal, 11)
            .frame(height: 29)
            .contentShape(Capsule())
        }
          .buttonStyle(.plain)
          .focusable(false)
          .tideGlassCapsule(
            tint: selected ? Color.accentColor.opacity(0.46) : nil,
            interactive: true
          )
          .accessibilityValue(selected ? "已选择" : "未选择")
      }
    }
  }

  private var customRangePicker: some View {
    HStack(spacing: 8) {
      DatePicker("开始", selection: $customStart, displayedComponents: .date)
        .labelsHidden()
        .controlSize(.small)
      Text("–").foregroundStyle(.secondary)
      DatePicker("结束", selection: $customEnd, in: customStart..., displayedComponents: .date)
        .labelsHidden()
        .controlSize(.small)
    }
    .padding(.horizontal, 11)
    .frame(height: 36)
    .tideGlassCapsule()
  }

  private func statisticNumber(title: String, value: Int, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
      Text("\(value)")
        .font(.system(size: 29, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
    }
    .frame(width: 52, alignment: .leading)
  }

  private var focusChart: some View {
    Chart(stats.daily) { point in
      BarMark(
        x: .value("日期", point.day, unit: bucket == .month ? .month : .day),
        y: .value("分钟", Double(point.seconds) / 60)
      )
      .foregroundStyle(Color.accentColor.opacity(point.seconds > 0 ? 0.86 : 0.16))
      .cornerRadius(3)
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: min(7, max(2, stats.daily.count)))) { value in
        AxisGridLine().foregroundStyle(.clear)
        AxisTick().foregroundStyle(.clear)
        AxisValueLabel {
          if let date = value.as(Date.self) {
            Text(axisLabel(date))
              .font(.system(size: 8))
              .foregroundStyle(Color.primary.opacity(0.4))
          }
        }
      }
    }
    .chartYAxis(.hidden)
    .frame(height: 112)
    .accessibilityLabel("\(range.summaryTitle)柱状图")
  }

  private var distributionChart: some View {
    Chart(stats.tagDistribution) { item in
      SectorMark(
        angle: .value("时间", item.seconds),
        innerRadius: .ratio(0.55),
        angularInset: 1
      )
      .foregroundStyle(Color(hex: item.colorHex))
    }
    .frame(width: 105, height: 105)
    .chartLegend(.hidden)
    .accessibilityLabel("专注时间标签分布")
  }

  private var dateRangeLabel: String {
    let calendar = Calendar.current
    let start = interval.start
    let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

    if calendar.isDate(start, inSameDayAs: inclusiveEnd) {
      return dateLabel(start, includesYear: true, calendar: calendar)
    }

    let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: inclusiveEnd)
    return "\(dateLabel(start, includesYear: true, calendar: calendar)) – \(dateLabel(inclusiveEnd, includesYear: !sameYear, calendar: calendar))"
  }

  private func dateLabel(_ date: Date, includesYear: Bool, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let monthAndDay = "\(components.month ?? 1)月\(components.day ?? 1)日"
    guard includesYear else { return monthAndDay }
    return "\(components.year ?? 1)年\(monthAndDay)"
  }

  private func selectedInterval(calendar: Calendar = .current) -> DateInterval {
    let now = controller.currentTime
    let today = calendar.startOfDay(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
    switch range {
    case .day:
      return DateInterval(start: today, end: tomorrow)
    case .week:
      return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: today, end: tomorrow)
    case .month:
      return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: today, end: tomorrow)
    case .year:
      return calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: today, end: tomorrow)
    case .all:
      let earliest = controller.sessions.map(\.endedAt).min().map(calendar.startOfDay(for:)) ?? today
      return DateInterval(start: earliest, end: tomorrow)
    case .custom:
      let start = calendar.startOfDay(for: min(customStart, customEnd))
      let endDay = calendar.startOfDay(for: max(customStart, customEnd))
      let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? tomorrow
      return DateInterval(start: start, end: end)
    }
  }

  private func compactDuration(_ seconds: Int) -> String {
    let minutes = max(0, seconds) / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    let remainder = minutes % 60
    return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
  }

  private func distributionLabel(_ seconds: Int) -> String {
    let percentage = stats.totalFocusSeconds == 0
      ? 0
      : Int((Double(seconds) / Double(stats.totalFocusSeconds) * 100).rounded())
    return "\(compactDuration(seconds))  \(percentage)%"
  }

  private func axisLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = bucket == .month ? "M月" : "E"
    return formatter.string(from: date)
  }
}
