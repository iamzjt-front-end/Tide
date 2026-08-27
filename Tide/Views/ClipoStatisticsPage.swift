import Charts
import SwiftUI

enum ClipoStatsRange: String, CaseIterable, Identifiable {
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

  func axisLabelStyle(bucket: PomodoroStatistics.Bucket) -> ClipoStatisticsAxisLabelStyle {
    switch self {
    case .day:
      return .monthAndDay
    case .week:
      return .weekday
    case .month:
      return .dayOfMonth
    case .year:
      return .month
    case .all, .custom:
      return switch bucket {
      case .day: .monthAndDay
      case .month: .month
      }
    }
  }
}

enum ClipoStatisticsAxisLabelStyle: Equatable, Sendable {
  case weekday
  case dayOfMonth
  case month
  case monthAndDay
}

private enum CustomRangeBoundary: Sendable, Equatable {
  case start
  case end
}

private enum CustomRangeSelectionPhase: Sendable, Equatable {
  case complete
  case selectingStart
  case selectingEnd
}

private enum CustomRangePreset: String, CaseIterable, Identifiable, Sendable {
  case currentYear
  case previousYear
  case lastThreeMonths
  case lastSixMonths
  case lastTwelveMonths
  case lastTwentyFourMonths

  var id: Self { self }

  var title: String {
    switch self {
    case .currentYear: "今年"
    case .previousYear: "去年"
    case .lastThreeMonths: "近 3 个月"
    case .lastSixMonths: "近 6 个月"
    case .lastTwelveMonths: "近 12 个月"
    case .lastTwentyFourMonths: "近 24 个月"
    }
  }

  var rollingMonthCount: Int? {
    switch self {
    case .currentYear, .previousYear: nil
    case .lastThreeMonths: 3
    case .lastSixMonths: 6
    case .lastTwelveMonths: 12
    case .lastTwentyFourMonths: 24
    }
  }
}

enum ClipoStatisticsAxisLabelFormatter {
  static func text(
    for date: Date,
    style: ClipoStatisticsAxisLabelStyle,
    calendar: Calendar = .current
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = switch style {
    case .weekday: "EEE"
    case .dayOfMonth: "d日"
    case .month: "M月"
    case .monthAndDay: "M/d"
    }
    return formatter.string(from: date)
  }
}

struct ClipoStatisticsPage: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var controller: PomodoroController

  @State private var range: ClipoStatsRange = .week
  @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
  @State private var customEnd = Date.now
  @State private var draftCustomStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
  @State private var draftCustomEnd = Date.now
  @State private var customRangeSelectionPhase: CustomRangeSelectionPhase = .complete
  @State private var customCalendarMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
  @State private var showingCustomRangeEditor = false
  @State private var displayedStats = PomodoroStatisticsSnapshot.empty
  @State private var hasAnimatedEntrance = false
  @State private var filtersVisible = false
  @State private var summaryVisible = false
  @State private var chartVisible = false
  @State private var distributionVisible = false
  @State private var chartProgress = 0.0
  @State private var distributionProgress = 0.0
  @State private var dataOpacity = 1.0
  @State private var hoveredDay: Date?

  private var interval: DateInterval { selectedInterval() }

  private var bucket: PomodoroStatistics.Bucket {
    let days = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
    return range == .year || range == .all || days > 90 ? .month : .day
  }

  private var calculatedStats: PomodoroStatisticsSnapshot {
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

        Text(dateRangeLabel)
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .contentTransition(.numericText())
          .accessibilityLabel("统计日期范围，\(dateRangeLabel)")
      }
      .padding(.top, 9)
      .opacity(filtersVisible ? 1 : 0)
      .offset(y: filtersVisible ? 0 : -5)

      GlassCard {
        HStack(alignment: .center, spacing: 18) {
          VStack(alignment: .leading, spacing: 5) {
            Label {
              Text(range.summaryTitle)
            } icon: {
              Image(systemName: "clock")
                .foregroundStyle(Color.accentColor)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)

            Text(compactDuration(displayedStats.totalFocusSeconds))
              .font(.system(size: 31, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.primary)
              .contentTransition(.numericText(value: Double(displayedStats.totalFocusSeconds)))

            Text("平均每次 \(compactDuration(displayedStats.averageSeconds))")
              .font(.system(size: 9, weight: .medium, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.secondary.opacity(0.82))
              .contentTransition(.numericText(value: Double(displayedStats.averageSeconds)))
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          VStack(alignment: .trailing, spacing: 5) {
            Label {
              Text("完成番茄")
            } icon: {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text("\(displayedStats.completedCount)")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
                .contentTransition(.numericText(value: Double(displayedStats.completedCount)))

              Text("个")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            }
          }
          .frame(minWidth: 76, alignment: .trailing)
        }
        .frame(minHeight: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(range.summaryTitle)，\(compactDuration(displayedStats.totalFocusSeconds))，完成 \(displayedStats.completedCount) 个，平均每次 \(compactDuration(displayedStats.averageSeconds))"
        )
      }
      .opacity(summaryVisible ? dataOpacity : 0)
      .offset(y: summaryVisible ? 0 : 8)
      .scaleEffect(summaryVisible ? 1 : 0.985, anchor: .top)

      GlassCard {
        VStack(alignment: .leading, spacing: 9) {
          chartHeaderRow(
            title: range.summaryTitle,
            summary: hasFocusableDailyData ? hoveredBarSummary : nil
          )
          ZStack {
            focusChart
            if displayedStats.daily.allSatisfy({ $0.seconds == 0 }) {
              Text("暂无完成记录")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            }
          }
        }
      }
      .opacity(chartVisible ? dataOpacity : 0)
      .offset(y: chartVisible ? 0 : 10)
      .scaleEffect(chartVisible ? 1 : 0.985, anchor: .top)

      GlassCard {
        VStack(alignment: .leading, spacing: 10) {
          Text("专注时间分布")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
          if displayedStats.tagDistribution.isEmpty {
            Text("暂无专注记录")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
              .frame(maxWidth: .infinity, minHeight: 70)
          } else {
            HStack(spacing: 16) {
              distributionChart
              VStack(spacing: 7) {
                ForEach(displayedStats.tagDistribution.prefix(4)) { item in
                  HStack(spacing: 6) {
                    Circle()
                      .fill(Color(hex: item.colorHex))
                      .frame(width: 7, height: 7)
                    Text(item.name)
                      .font(.system(size: 10, weight: .medium))
                      .lineLimit(1)
                    Spacer()
                    Text(distributionLabel(item.seconds))
                      .font(.system(size: 9, weight: .semibold, design: .rounded))
                      .foregroundStyle(.secondary)
                      .contentTransition(.numericText(value: Double(item.seconds)))
                  }
                }
              }
            }
          }
        }
      }
      .opacity(distributionVisible ? dataOpacity : 0)
      .offset(y: distributionVisible ? 0 : 10)
      .scaleEffect(distributionVisible ? 1 : 0.985, anchor: .top)
    }
    .padding(.horizontal, 46)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onChange(of: range) {
      setHoveredDay(nil)
    }
    .onChange(of: statisticsAnimationKey) {
      if let day = hoveredDay,
        !displayedStats.daily.contains(where: { $0.day == day })
      {
        hoveredDay = nil
      }
    }
    .task(id: statisticsAnimationKey) {
      await animateStatistics(to: calculatedStats)
    }
  }

  private var rangePicker: some View {
    HStack(spacing: 5) {
      ForEach(ClipoStatsRange.allCases) { item in
        let selected = item == range || (item == .custom && showingCustomRangeEditor)
        Button {
          if item == .custom {
            presentCustomRangeEditor()
          } else {
            range = item
          }
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
          .popover(
            isPresented: customRangeEditorPresentation(for: item),
            arrowEdge: .top
          ) {
            customRangeEditor
          }
      }
    }
  }

  private var customRangeEditor: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("自定义范围")
            .font(.system(size: 14, weight: .bold))
          Text("快捷选择，或依次选择开始和结束日期")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          showingCustomRangeEditor = false
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .tideGlassCircle(interactive: true)
        .accessibilityLabel("取消自定义范围")
      }

      HStack(spacing: 7) {
        customBoundaryButton(
          boundary: .start,
          title: "开始",
          date: draftCustomStart
        )

        Image(systemName: "arrow.right")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.tertiary)

        customBoundaryButton(
          boundary: .end,
          title: "结束",
          date: draftCustomEnd
        )
      }

      customRangePresets

      CustomDateRangeCalendar(
        start: $draftCustomStart,
        end: $draftCustomEnd,
        selectionPhase: $customRangeSelectionPhase,
        visibleMonth: $customCalendarMonth
      )

      HStack(spacing: 8) {
        Text(customDraftRangeLabel)
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer()

        Button("取消") {
          showingCustomRangeEditor = false
        }
        .buttonStyle(ClipoCapsuleButtonStyle())
        .focusable(false)

        Button("应用") {
          applyCustomRange()
        }
        .buttonStyle(ClipoCapsuleButtonStyle(prominent: true))
        .focusable(false)
      }
    }
    .padding(16)
    .frame(width: 330)
    .onExitCommand {
      showingCustomRangeEditor = false
    }
  }

  private var customRangePresets: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text("长周期快捷选择")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)

        Spacer()

        Text("选择后仍可调整")
          .font(.system(size: 8, weight: .medium))
          .foregroundStyle(.tertiary)
      }

      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 2),
        spacing: 5
      ) {
        ForEach(CustomRangePreset.allCases) { preset in
          let selected = isSelectedPreset(preset)
          Button {
            selectPreset(preset)
          } label: {
            Text(preset.title)
              .font(.system(size: 9, weight: selected ? .semibold : .medium, design: .rounded))
              .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.7))
              .frame(maxWidth: .infinity, minHeight: 27)
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .focusable(false)
          .background {
            Capsule()
              .fill(
                selected
                  ? Color.accentColor.opacity(0.15)
                  : Color.primary.opacity(0.045)
              )
              .overlay {
                Capsule()
                  .stroke(
                    selected
                      ? Color.accentColor.opacity(0.38)
                      : Color.primary.opacity(0.07),
                    lineWidth: 0.7
                  )
              }
          }
          .accessibilityValue(selected ? "当前范围" : "未选择")
        }
      }
    }
  }

  private func customBoundaryButton(
    boundary: CustomRangeBoundary,
    title: String,
    date: Date
  ) -> some View {
    let selected = switch boundary {
    case .start:
      customRangeSelectionPhase == .selectingStart
    case .end:
      customRangeSelectionPhase == .selectingEnd
    }
    return Button {
      customRangeSelectionPhase = switch boundary {
      case .start: .selectingStart
      case .end: .selectingEnd
      }
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(editorDateLabel(date))
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.8))
          .contentTransition(.numericText())
      }
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
      .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassRect(
      cornerRadius: 11,
      tint: selected ? Color.accentColor.opacity(0.24) : nil,
      interactive: true
    )
    .accessibilityLabel("\(title)日期，\(editorDateLabel(date))")
    .accessibilityValue(selected ? "正在编辑" : "未编辑")
  }

  private var customDraftRangeLabel: String {
    let calendar = Calendar.current
    let sameYear = calendar.component(.year, from: draftCustomStart)
      == calendar.component(.year, from: draftCustomEnd)
    return "\(dateLabel(draftCustomStart, includesYear: true, calendar: calendar)) – \(dateLabel(draftCustomEnd, includesYear: !sameYear, calendar: calendar))"
  }

  private func selectPreset(_ preset: CustomRangePreset) {
    let dates = dates(for: preset)
    withAnimation(reduceMotion ? nil : .snappy(duration: 0.24, extraBounce: 0)) {
      draftCustomStart = dates.start
      draftCustomEnd = dates.end
      customRangeSelectionPhase = .complete
      customCalendarMonth = Calendar.current.dateInterval(of: .month, for: dates.end)?.start
        ?? dates.end
    }
  }

  private func isSelectedPreset(_ preset: CustomRangePreset) -> Bool {
    let dates = dates(for: preset)
    let calendar = Calendar.current
    return calendar.isDate(draftCustomStart, inSameDayAs: dates.start)
      && calendar.isDate(draftCustomEnd, inSameDayAs: dates.end)
  }

  private func dates(for preset: CustomRangePreset) -> (start: Date, end: Date) {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4

    let today = calendar.startOfDay(for: controller.currentTime)
    switch preset {
    case .currentYear:
      let start = calendar.dateInterval(of: .year, for: today)?.start ?? today
      return (start, today)
    case .previousYear:
      let previousDate = calendar.date(byAdding: .year, value: -1, to: today) ?? today
      let interval = calendar.dateInterval(of: .year, for: previousDate)
      let start = interval?.start ?? previousDate
      let end = interval.flatMap { calendar.date(byAdding: .day, value: -1, to: $0.end) }
        ?? previousDate
      return (start, end)
    case .lastThreeMonths, .lastSixMonths, .lastTwelveMonths, .lastTwentyFourMonths:
      let boundary = calendar.date(
        byAdding: .month,
        value: -(preset.rollingMonthCount ?? 0),
        to: today
      ) ?? today
      let start = calendar.date(byAdding: .day, value: 1, to: boundary) ?? boundary
      return (start, today)
    }
  }

  private func editorDateLabel(_ date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 1)/\(components.month ?? 1)/\(components.day ?? 1)"
  }

  private func customRangeEditorPresentation(for item: ClipoStatsRange) -> Binding<Bool> {
    Binding(
      get: { item == .custom && showingCustomRangeEditor },
      set: { isPresented in
        guard item == .custom else { return }
        showingCustomRangeEditor = isPresented
      }
    )
  }

  private func presentCustomRangeEditor() {
    draftCustomStart = customStart
    draftCustomEnd = customEnd
    customRangeSelectionPhase = .complete
    customCalendarMonth = Calendar.current.dateInterval(of: .month, for: customStart)?.start
      ?? Calendar.current.startOfDay(for: customStart)
    showingCustomRangeEditor = true
  }

  private func applyCustomRange() {
    let calendar = Calendar.current
    customStart = calendar.startOfDay(for: min(draftCustomStart, draftCustomEnd))
    customEnd = calendar.startOfDay(for: max(draftCustomStart, draftCustomEnd))
    range = .custom
    hoveredDay = nil
    showingCustomRangeEditor = false
  }

  private var focusChart: some View {
    Chart(displayedStats.daily) { point in
      BarMark(
        x: .value("日期", point.day, unit: bucket == .month ? .month : .day),
        y: .value("分钟", Double(point.seconds) / 60 * chartProgress)
      )
      .foregroundStyle(barColor(for: point))
      .cornerRadius(3)
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: min(7, max(2, displayedStats.daily.count)))) { value in
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
    .chartOverlay { chart in
      GeometryReader { geometry in
        let plotRect = chart.plotFrame.map { geometry[$0] } ?? CGRect(origin: .zero, size: geometry.size)

        Color.clear
          .contentShape(Rectangle())
          .onContinuousHover { phase in
            updateChartHover(phase, plotRect: plotRect, chart: chart)
          }
      }
    }
    .frame(height: 112)
    .animation(reduceMotion ? nil : .smooth(duration: 0.56), value: chartProgress)
    .accessibilityLabel("\(range.summaryTitle)柱状图")
  }

  private var hoveredPoint: FocusDayPoint? {
    guard let hoveredDay else { return nil }
    return displayedStats.daily.first { $0.day == hoveredDay }
  }

  private var hasFocusableDailyData: Bool {
    !displayedStats.daily.isEmpty && !displayedStats.daily.allSatisfy { $0.seconds == 0 }
  }

  private func barColor(for point: FocusDayPoint) -> Color {
    let isHovered = hoveredPoint?.day == point.day
    if point.seconds <= 0 {
      return Color.accentColor.opacity(isHovered ? 0.42 : 0.16)
    }
    if hoveredPoint == nil {
      return Color.accentColor.opacity(0.86)
    }
    return Color.accentColor.opacity(isHovered ? 1 : 0.34)
  }

  private func updateChartHover(_ phase: HoverPhase, plotRect: CGRect, chart: ChartProxy) {
    switch phase {
    case .active(let location):
      guard hasFocusableDailyData else {
        setHoveredDay(nil)
        return
      }
      let clampedX = min(max(location.x, plotRect.minX), plotRect.maxX)
      guard
        let (value, _) = chart.value(
          at: CGPoint(x: clampedX, y: plotRect.midY),
          as: (Date, Double).self
        )
      else {
        setHoveredDay(nil)
        return
      }
      setHoveredDay(nearestBucketStart(for: value))
    case .ended:
      setHoveredDay(nil)
    }
  }

  private func setHoveredDay(_ day: Date?) {
    guard day != hoveredDay else { return }
    hoveredDay = day
  }

  private var hoverAnimation: Animation? {
    reduceMotion ? nil : .snappy(duration: 0.15, extraBounce: 0)
  }

  private func nearestBucketStart(for date: Date) -> Date? {
    let calendar = Calendar.current
    let granularity: Calendar.Component = bucket == .month ? .month : .day
    let target = calendar.dateInterval(of: granularity, for: date)?.start ?? date
    let halfUnit: TimeInterval = bucket == .month ? 15.5 * 86_400 : 43_200
    guard
      let nearest = displayedStats.daily.min(by: {
        abs($0.day.timeIntervalSince(target)) < abs($1.day.timeIntervalSince(target))
      }),
      abs(nearest.day.timeIntervalSince(target)) <= halfUnit
    else { return nil }
    return nearest.day
  }

  @ViewBuilder
  private func chartHeaderRow(title: String, summary: String?) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .trailing) {
        headerSummaryChip(summary)
      }
  }

  private func headerSummaryChip(_ summary: String?) -> some View {
    Text(summary ?? " ")
      .font(.system(size: 9, weight: .semibold, design: .rounded))
      .monospacedDigit()
      .lineLimit(1)
      .foregroundStyle(Color.primary.opacity(0.68))
      .padding(.horizontal, 10)
      .frame(height: 21)
      .fixedSize()
      .background {
        Capsule()
          .fill(Color.primary.opacity(0.05))
          .overlay {
            Capsule()
              .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
          }
      }
      .opacity(summary == nil ? 0 : 1)
      .animation(hoverAnimation, value: summary == nil)
  }

  private var hoveredBarSummary: String? {
    guard let point = hoveredPoint else { return nil }
    let title = tooltipTitle(for: point.day)
    guard point.seconds > 0 else { return "\(title) · 暂无专注" }
    return "\(title) · \(compactDuration(point.seconds)) · \(point.completedCount) 个番茄"
  }

  private func tooltipTitle(for date: Date) -> String {
    let calendar = Calendar.current
    if bucket == .month {
      let components = calendar.dateComponents([.year, .month], from: date)
      return "\(components.year ?? 1)年\(components.month ?? 1)月"
    }
    if calendar.isDateInToday(date) { return "今天" }
    let weekday = ClipoStatisticsAxisLabelFormatter.text(for: date, style: .weekday)
    let monthAndDay = ClipoStatisticsAxisLabelFormatter.text(for: date, style: .monthAndDay)
    return "\(weekday) \(monthAndDay)"
  }

  private var distributionChart: some View {
    Chart(displayedStats.tagDistribution) { item in
      SectorMark(
        angle: .value("时间", item.seconds),
        innerRadius: .ratio(0.55),
        angularInset: 1
      )
      .foregroundStyle(Color(hex: item.colorHex))
    }
    .frame(width: 105, height: 105)
    .chartLegend(.hidden)
    .scaleEffect(0.84 + 0.16 * distributionProgress)
    .rotationEffect(.degrees(-8 * (1 - distributionProgress)))
    .opacity(distributionProgress)
    .animation(
      reduceMotion ? nil : Animation.smooth(duration: 0.52),
      value: distributionProgress
    )
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
      return PomodoroStatistics.currentWeekInterval(containing: now, calendar: calendar)
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

  private func distributionPercentage(_ seconds: Int) -> Int {
    displayedStats.totalFocusSeconds == 0
      ? 0
      : Int((Double(seconds) / Double(displayedStats.totalFocusSeconds) * 100).rounded())
  }

  private func distributionLabel(_ seconds: Int) -> String {
    "\(compactDuration(seconds))  \(distributionPercentage(seconds))%"
  }

  private func axisLabel(_ date: Date) -> String {
    ClipoStatisticsAxisLabelFormatter.text(
      for: date,
      style: range.axisLabelStyle(bucket: bucket)
    )
  }

  private var statisticsAnimationKey: StatisticsAnimationKey {
    let snapshot = calculatedStats
    return StatisticsAnimationKey(
      range: range.rawValue,
      start: interval.start,
      end: interval.end,
      totalFocusSeconds: snapshot.totalFocusSeconds,
      completedCount: snapshot.completedCount,
      dailySeconds: snapshot.daily.map(\.seconds),
      distribution: snapshot.tagDistribution.map { "\($0.id)|\($0.seconds)" }
    )
  }

  @MainActor
  private func animateStatistics(to snapshot: PomodoroStatisticsSnapshot) async {
    if reduceMotion {
      displayedStats = snapshot
      filtersVisible = true
      summaryVisible = true
      chartVisible = true
      distributionVisible = true
      chartProgress = 1
      distributionProgress = 1
      dataOpacity = 1
      hasAnimatedEntrance = true
      return
    }

    if !hasAnimatedEntrance {
      hasAnimatedEntrance = true
      displayedStats = .empty
      chartProgress = 0
      distributionProgress = 0

      withAnimation(.easeOut(duration: 0.18)) {
        filtersVisible = true
      }
      guard await pause(for: .milliseconds(55)) else { return }

      withAnimation(.snappy(duration: 0.38, extraBounce: 0)) {
        displayedStats = snapshot
        summaryVisible = true
      }
      guard await pause(for: .milliseconds(85)) else { return }

      withAnimation(.smooth(duration: 0.56)) {
        chartVisible = true
        chartProgress = 1
      }
      guard await pause(for: .milliseconds(80)) else { return }

      withAnimation(.smooth(duration: 0.52)) {
        distributionVisible = true
        distributionProgress = 1
      }
      return
    }

    withAnimation(.easeOut(duration: 0.1)) {
      dataOpacity = 0.64
      chartProgress = 0
      distributionProgress = 0
    }
    guard await pause(for: .milliseconds(75)) else { return }

    withAnimation(.snappy(duration: 0.46, extraBounce: 0)) {
      displayedStats = snapshot
      dataOpacity = 1
      chartProgress = 1
      distributionProgress = 1
    }
  }

  private func pause(for duration: Duration) async -> Bool {
    do {
      try await Task.sleep(for: duration)
      return !Task.isCancelled
    } catch {
      return false
    }
  }
}

private struct StatisticsAnimationKey: Equatable {
  var range: String
  var start: Date
  var end: Date
  var totalFocusSeconds: Int
  var completedCount: Int
  var dailySeconds: [Int]
  var distribution: [String]
}

private struct CustomDateRangeCalendar: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Binding var start: Date
  @Binding var end: Date
  @Binding var selectionPhase: CustomRangeSelectionPhase
  @Binding var visibleMonth: Date

  private let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]
  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 0, alignment: .center),
    count: 7
  )

  private var calendar: Calendar {
    var value = Calendar.current
    value.firstWeekday = 2
    value.minimumDaysInFirstWeek = 4
    return value
  }

  private var displayedMonth: Date {
    calendar.dateInterval(of: .month, for: visibleMonth)?.start
      ?? calendar.startOfDay(for: visibleMonth)
  }

  private var calendarDays: [Date] {
    let firstWeekday = calendar.component(.weekday, from: displayedMonth)
    let daysFromMonday = (firstWeekday + 5) % 7
    let gridStart = calendar.date(
      byAdding: .day,
      value: -daysFromMonday,
      to: displayedMonth
    ) ?? displayedMonth

    return (0..<42).compactMap {
      calendar.date(byAdding: .day, value: $0, to: gridStart)
    }
  }

  var body: some View {
    VStack(spacing: 8) {
      monthHeader

      LazyVGrid(columns: columns, spacing: 0) {
        ForEach(weekdayTitles, id: \.self) { title in
          Text(title)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary.opacity(0.72))
            .frame(maxWidth: .infinity, minHeight: 18)
            .accessibilityHidden(true)
        }
      }

      LazyVGrid(columns: columns, spacing: 2) {
        ForEach(calendarDays, id: \.self) { date in
          dayButton(date)
        }
      }
      .id(displayedMonth)
      .transition(.opacity)
    }
    .padding(.vertical, 2)
    .animation(
      reduceMotion ? nil : .snappy(duration: 0.24, extraBounce: 0),
      value: start
    )
    .animation(
      reduceMotion ? nil : .snappy(duration: 0.24, extraBounce: 0),
      value: end
    )
  }

  private var monthHeader: some View {
    HStack(spacing: 8) {
      monthNavigationButton(
        systemName: "chevron.left",
        accessibilityLabel: "上个月",
        offset: -1
      )

      Spacer(minLength: 4)

      VStack(spacing: 1) {
        Text(monthTitle)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())

        Text(selectionPrompt)
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(
            selectionPhase == .complete
              ? Color.secondary
              : Color.accentColor
          )
          .contentTransition(.numericText())
      }
      .accessibilityElement(children: .combine)

      Spacer(minLength: 4)

      monthNavigationButton(
        systemName: "chevron.right",
        accessibilityLabel: "下个月",
        offset: 1
      )
    }
  }

  private func monthNavigationButton(
    systemName: String,
    accessibilityLabel: String,
    offset: Int
  ) -> some View {
    Button {
      guard let month = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
        return
      }
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
        visibleMonth = month
      }
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 9, weight: .bold))
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassCircle(interactive: true)
    .accessibilityLabel(accessibilityLabel)
  }

  private func dayButton(_ date: Date) -> some View {
    let endpoint = endpoint(for: date)
    let inDisplayedMonth = isInDisplayedMonth(date)

    return Button {
      select(date)
    } label: {
      ZStack {
        rangeBackground(for: date, endpoint: endpoint)

        Text("\(calendar.component(.day, from: date))")
          .font(.system(size: 10, weight: endpoint == nil ? .medium : .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(
            endpoint == nil
              ? Color.primary.opacity(inDisplayedMonth ? 0.86 : 0.3)
              : Color.white
          )

        if calendar.isDateInToday(date), endpoint == nil {
          Circle()
            .fill(Color.accentColor)
            .frame(width: 3, height: 3)
            .offset(y: 11)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 32)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .accessibilityLabel(accessibilityDateLabel(date))
    .accessibilityValue(accessibilityValue(for: date, endpoint: endpoint))
  }

  @ViewBuilder
  private func rangeBackground(for date: Date, endpoint: CustomRangeBoundary?) -> some View {
    if isInSelectedRange(date) {
      ZStack {
        HStack(spacing: 0) {
          Rectangle()
            .fill(Color.accentColor.opacity(hasSelectedDayBefore(date) ? 0.13 : 0))
          Rectangle()
            .fill(Color.accentColor.opacity(hasSelectedDayAfter(date) ? 0.13 : 0))
        }
        .frame(height: 24)

        if endpoint != nil {
          Circle()
            .fill(Color.accentColor.opacity(0.92))
            .frame(width: 28, height: 28)
        }
      }
    } else if calendar.isDateInToday(date) {
      Circle()
        .stroke(Color.accentColor.opacity(0.62), lineWidth: 1)
        .frame(width: 28, height: 28)
    }
  }

  private func select(_ date: Date) {
    let day = calendar.startOfDay(for: date)
    let currentStart = calendar.startOfDay(for: start)

    withAnimation(reduceMotion ? nil : .snappy(duration: 0.24, extraBounce: 0)) {
      switch selectionPhase {
      case .complete, .selectingStart:
        start = day
        end = day
        selectionPhase = .selectingEnd
      case .selectingEnd:
        if day < currentStart {
          start = day
          end = currentStart
        } else {
          end = day
        }
        selectionPhase = .complete
      }

      if !isInDisplayedMonth(day) {
        visibleMonth = calendar.dateInterval(of: .month, for: day)?.start ?? day
      }
    }
  }

  private func endpoint(for date: Date) -> CustomRangeBoundary? {
    if calendar.isDate(date, inSameDayAs: start) {
      return .start
    }
    if calendar.isDate(date, inSameDayAs: end) {
      return .end
    }
    return nil
  }

  private func isInSelectedRange(_ date: Date) -> Bool {
    let day = calendar.startOfDay(for: date)
    let lowerBound = calendar.startOfDay(for: min(start, end))
    let upperBound = calendar.startOfDay(for: max(start, end))
    return day >= lowerBound && day <= upperBound
  }

  private func hasSelectedDayBefore(_ date: Date) -> Bool {
    guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
      return false
    }
    return isInSelectedRange(previous)
  }

  private func hasSelectedDayAfter(_ date: Date) -> Bool {
    guard let next = calendar.date(byAdding: .day, value: 1, to: date) else {
      return false
    }
    return isInSelectedRange(next)
  }

  private func isInDisplayedMonth(_ date: Date) -> Bool {
    calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
  }

  private var monthTitle: String {
    let components = calendar.dateComponents([.year, .month], from: displayedMonth)
    return "\(components.year ?? 1)年\(components.month ?? 1)月"
  }

  private var selectionPrompt: String {
    switch selectionPhase {
    case .complete:
      return "已选择 \(selectedDayCount) 天"
    case .selectingStart:
      return "请选择开始日期"
    case .selectingEnd:
      return "请选择结束日期"
    }
  }

  private var selectedDayCount: Int {
    let lowerBound = calendar.startOfDay(for: min(start, end))
    let upperBound = calendar.startOfDay(for: max(start, end))
    let dayDifference = calendar.dateComponents(
      [.day],
      from: lowerBound,
      to: upperBound
    ).day ?? 0
    return max(1, dayDifference + 1)
  }

  private func accessibilityDateLabel(_ date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 1)年\(components.month ?? 1)月\(components.day ?? 1)日"
  }

  private func accessibilityValue(
    for date: Date,
    endpoint: CustomRangeBoundary?
  ) -> String {
    if endpoint == .start, calendar.isDate(start, inSameDayAs: end) {
      return "开始和结束日期"
    }
    if endpoint == .start {
      return "开始日期"
    }
    if endpoint == .end {
      return "结束日期"
    }
    if isInSelectedRange(date) {
      return "所选范围内"
    }
    return "未选择"
  }
}
