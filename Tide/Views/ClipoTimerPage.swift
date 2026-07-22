import SwiftUI

struct ClipoTimerPage: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  var controller: PomodoroController
  var entranceRevision: Int = 0
  var entranceDelayMilliseconds: Int = 0
  var onShowStatistics: () -> Void

  @State private var showingStopConfirmation = false
  @State private var showingTagCreator = false
  @State private var showingLabelPicker = false
  @State private var dialVisible = false
  @State private var contextVisible = false
  @State private var controlsVisible = false
  @State private var ringEntranceProgress = 0.0

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        PomodoroDial(
          controller: controller,
          entranceProgress: ringEntranceProgress
        )
          .frame(height: 292, alignment: .top)
          .opacity(dialVisible ? 1 : 0)
          .scaleEffect(dialVisible ? 1 : 0.92, anchor: .center)
          .offset(y: dialVisible ? 0 : 14)
          .blur(radius: dialVisible ? 0 : 4)

        contextRow
          .frame(height: 42)
          .padding(.top, 6)
          .padding(.bottom, 24)
          .opacity(contextVisible ? 1 : 0)
          .scaleEffect(contextVisible ? 1 : 0.96)
          .offset(y: contextVisible ? 0 : 13)

        controls
          .padding(.top, 5)
          .opacity(controlsVisible ? 1 : 0)
          .scaleEffect(controlsVisible ? 1 : 0.95, anchor: .top)
          .offset(y: controlsVisible ? 0 : 17)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

      if showingTagCreator {
        Color.black.opacity(0.3)
          .contentShape(Rectangle())
          .onTapGesture { showingTagCreator = false }
        CreateTagPopover(
          onCancel: { showingTagCreator = false },
          onCreate: { name, color in
            if controller.addTag(name: name, colorHex: color) {
              showingTagCreator = false
            }
          }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.48), radius: 25, y: 12)
        .offset(y: 18)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
    }
    .onChange(of: controller.snapshot.runState) { _, newState in
      if newState == .idle { showingStopConfirmation = false }
    }
    .task(id: entranceRevision) {
      await animateEntrance()
    }
  }

  @MainActor
  private func animateEntrance() async {
    dialVisible = false
    contextVisible = false
    controlsVisible = false
    ringEntranceProgress = 0

    guard !reduceMotion else {
      dialVisible = true
      contextVisible = true
      controlsVisible = true
      ringEntranceProgress = 1
      return
    }

    await Task.yield()
    guard !Task.isCancelled else { return }
    if entranceDelayMilliseconds > 0 {
      guard await entrancePause(for: .milliseconds(entranceDelayMilliseconds)) else { return }
    }

    withAnimation(.smooth(duration: 0.52)) {
      dialVisible = true
      ringEntranceProgress = 1
    }
    guard await entrancePause(for: .milliseconds(120)) else { return }

    withAnimation(.smooth(duration: 0.36)) {
      contextVisible = true
    }
    guard await entrancePause(for: .milliseconds(100)) else { return }

    withAnimation(.smooth(duration: 0.38)) {
      controlsVisible = true
    }
  }

  private func entrancePause(for duration: Duration) async -> Bool {
    do {
      try await Task.sleep(for: duration)
      return !Task.isCancelled
    } catch {
      return false
    }
  }

  private var contextRow: some View {
    HStack(spacing: 10) {
      selectionControl
        .layoutPriority(1)
      todaySummary
        .frame(minWidth: 160)
    }
    .padding(.horizontal, 34)
  }

  private var todaySummary: some View {
    let today = controller.statistics(for: .today)
    return Button(action: onShowStatistics) {
      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "clock")
            .foregroundStyle(Color.accentColor)
          Text(TideFormatting.compactDuration(today.totalFocusSeconds))
            .foregroundStyle(.primary)
        }
        Text("·")
          .foregroundStyle(.tertiary)
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentColor)
          Text("\(today.completedCount) 个")
            .foregroundStyle(.primary)
        }
        Spacer(minLength: 2)
        Image(systemName: "chevron.right")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity)
      .frame(height: 31)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassCapsule(
      tint: Color.accentColor.opacity(colorScheme == .dark ? 0.045 : 0.1),
      interactive: true
    )
    .help("查看专注统计")
    .accessibilityLabel("查看统计，今日专注 \(TideFormatting.compactDuration(today.totalFocusSeconds))，完成 \(today.completedCount) 个")
    .accessibilityElement(children: .combine)
  }

  private var selectionControl: some View {
    Button {
      showingLabelPicker = true
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(Color(hex: controller.selectedFocusLabelColorHex ?? "#868E96"))
          .frame(width: 6, height: 6)
        Text(controller.selectedFocusLabelName ?? "无标签")
          .lineLimit(1)
          .truncationMode(.tail)
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.tertiary)
      }
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .frame(height: 31)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassCapsule(
      tint: Color(hex: controller.selectedFocusLabelColorHex ?? "#868E96")
        .opacity(colorScheme == .dark ? 0.14 : 0.24),
      interactive: true
    )
    .popover(isPresented: $showingLabelPicker, arrowEdge: .bottom) {
      FocusLabelPickerPopover(
        controller: controller,
        onCreate: {
          showingLabelPicker = false
          Task { @MainActor in
            await Task.yield()
            showingTagCreator = true
          }
        },
        onClose: { showingLabelPicker = false }
      )
    }
    .help(controller.snapshot.runState == .idle ? "选择专注标签" : "更改当前专注标签")
    .accessibilityLabel(
      "专注标签，\(controller.selectedFocusLabelName ?? "无标签")，可更改"
    )
  }

  private var controls: some View {
    TideGlassContainer(spacing: 46) {
      HStack(spacing: 46) {
        ClipoControlButton(
          symbol: primarySymbol,
          label: primaryTitle,
          enabled: true,
          role: .primary,
          action: primaryAction
        )

        if isBreakPhase {
          ClipoControlButton(
            symbol: "forward.end.fill",
            label: "跳过休息",
            enabled: true,
            role: .skipRest
          ) {
            controller.skipBreak()
          }
        } else {
          ClipoControlButton(
            symbol: "stop.fill",
            label: "停止",
            enabled: controller.snapshot.runState != .idle,
            role: .destructive
          ) {
            showingStopConfirmation = true
          }
          .popover(isPresented: $showingStopConfirmation, arrowEdge: .bottom) {
            ClipoConfirmationPopover(
              title: stopConfirmationTitle,
              message: stopConfirmationMessage,
              confirmTitle: stopConfirmationButtonTitle,
              destructive: true,
              onCancel: { showingStopConfirmation = false },
              onConfirm: {
                showingStopConfirmation = false
                controller.stop()
              }
            )
          }
        }
      }
    }
  }

  private var isBreakPhase: Bool {
    controller.snapshot.timerMode == .pomodoro && controller.snapshot.phase.isBreak
  }

  private var primaryTitle: String {
    return switch controller.snapshot.runState {
    case .idle:
      if controller.snapshot.timerMode == .pomodoro,
         controller.snapshot.phase.isBreak {
        "开始\(controller.snapshot.phase.title)"
      } else {
        "开始"
      }
    case .running: "暂停"
    case .paused: "继续"
    }
  }

  private var primarySymbol: String {
    return switch controller.snapshot.runState {
    case .running: "pause.fill"
    case .idle, .paused: "play.fill"
    }
  }

  private func primaryAction() {
    switch controller.snapshot.runState {
    case .idle: controller.start()
    case .running: controller.pause()
    case .paused: controller.resume()
    }
  }

  private var stopConfirmationTitle: String {
    if controller.snapshot.timerMode == .stopwatch { return "重置正计时" }
    return controller.snapshot.phase == .focus
      ? "停止专注"
      : "结束\(controller.snapshot.phase.title)"
  }

  private var stopConfirmationMessage: String {
    if controller.snapshot.timerMode == .stopwatch {
      return "当前累计时间将归零。"
    }
    if controller.snapshot.phase == .focus {
      return "当前实际专注时长会保存为一次提前完成，并计入本轮。"
    }
    return "结束后，下一次专注会进入待开始状态。"
  }

  private var stopConfirmationButtonTitle: String {
    if controller.snapshot.timerMode == .stopwatch { return "重置" }
    return controller.snapshot.phase == .focus ? "完成并停止" : "结束"
  }
}

private struct PomodoroDial: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var controller: PomodoroController
  var entranceProgress: Double = 1

  @Namespace private var modeSwitchNamespace
  @State private var editingBreakKind: BreakDurationKind?
  @State private var showingRoundEditor = false
  @State private var previewMinutes: Int?
  @State private var lastDragMinutes: Int?

  private let dialSize: CGFloat = 278
  private let ringInset: CGFloat = 7.5
  private let ringWidth: CGFloat = 15

  private var accent: Color {
    controller.snapshot.phase.isBreak
      ? Color(hex: "#69DB7C")
      : Color(hex: controller.currentAccentHex)
  }

  private var canAdjustFocusDuration: Bool {
    controller.snapshot.timerMode == .pomodoro &&
      controller.snapshot.phase == .focus &&
      controller.snapshot.runState == .idle
  }

  private var displayedFocusMinutes: Int {
    previewMinutes ?? controller.configuration.focusMinutes
  }

  private var displayedSeconds: Int {
    guard canAdjustFocusDuration, let previewMinutes else {
      return controller.displaySeconds
    }
    return previewMinutes * 60
  }

  private var displayedTime: String { TideFormatting.clock(displayedSeconds) }

  private var isModeSelectionExpanded: Bool {
    controller.snapshot.runState == .idle &&
      (controller.snapshot.timerMode == .stopwatch || controller.snapshot.phase == .focus) &&
      !controller.snapshot.isShowingCompletion
  }

  private var dialValueAnimation: Animation? {
    guard !reduceMotion else { return nil }
    return canAdjustFocusDuration
      ? .snappy(duration: 0.14, extraBounce: 0)
      : .linear(duration: 0.16)
  }

  private var coloredRingFraction: Double? {
    guard controller.snapshot.timerMode == .pomodoro else { return nil }
    if canAdjustFocusDuration {
      return PomodoroDialScale.fraction(for: displayedFocusMinutes)
    }
    guard controller.snapshot.phaseDurationSeconds > 0 else { return nil }
    return max(
      0,
      min(1, Double(controller.displaySeconds) / Double(controller.snapshot.phaseDurationSeconds))
    )
  }

  private var trackColor: Color {
    controller.snapshot.timerMode == .stopwatch
      ? Color.primary.opacity(0.09)
      : accent.opacity(colorScheme == .dark ? 0.1 : 0.15)
  }

  private var dialGlassTint: Color? {
    controller.snapshot.timerMode == .stopwatch
      ? nil
      : accent.opacity(colorScheme == .dark ? 0.04 : 0.08)
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(
          TideTheme.raisedSurface(colorScheme)
            .opacity(colorScheme == .dark ? 0.1 : 0.56)
        )
        .tideGlassCircle(tint: dialGlassTint)

      Circle()
        .strokeBorder(trackColor, lineWidth: 15)

      if let coloredRingFraction, coloredRingFraction > 0 {
        let visibleRingFraction = coloredRingFraction * entranceProgress
        Circle()
          .trim(from: 0, to: visibleRingFraction)
          .stroke(
            accent.opacity(colorScheme == .dark ? 0.9 : 1),
            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
          )
          .padding(ringInset)
          .rotationEffect(.degrees(-90))
          .shadow(
            color: accent.opacity(
              controller.snapshot.runState == .running
                ? (colorScheme == .dark ? 0.2 : 0.48)
                : 0
            ),
            radius: colorScheme == .dark ? 9 : 12
          )
          .animation(dialValueAnimation, value: coloredRingFraction)
          .animation(
            reduceMotion ? nil : .smooth(duration: 0.56),
            value: entranceProgress
          )
      }

      DialTickShape(major: false)
        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
      DialTickShape(major: true)
        .stroke(Color.primary.opacity(0.22), lineWidth: 1)

      VStack(spacing: 0) {
        modeSwitch
          .frame(height: 29)

        Spacer().frame(height: 22)

        Text(displayedTime)
          .font(.system(size: 51, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.primary)
          .contentTransition(.numericText(value: Double(displayedSeconds)))
          .animation(dialValueAnimation, value: displayedSeconds)
          .frame(height: 60)
          .accessibilityLabel("计时，\(displayedTime)")

        Spacer().frame(height: 9)

        detailRegion
          .frame(height: 80, alignment: .top)
      }

      if let coloredRingFraction, coloredRingFraction > 0 {
        let visibleRingFraction = coloredRingFraction * entranceProgress
        Circle()
          .fill(accent)
          .frame(width: 18, height: 18)
          .overlay {
            Circle()
              .stroke(Color.white.opacity(0.75), lineWidth: 1)
              .allowsHitTesting(false)
          }
          .shadow(color: accent.opacity(0.35), radius: 5, y: 2)
          .offset(y: -(dialSize / 2 - ringInset))
          .rotationEffect(.degrees(visibleRingFraction * 360))
          .opacity(entranceProgress)
          .animation(dialValueAnimation, value: coloredRingFraction)
          .animation(
            reduceMotion ? nil : .smooth(duration: 0.56),
            value: entranceProgress
          )
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }

      if canAdjustFocusDuration {
        DialRingHitShape(inset: ringInset, hitWidth: 42)
          .fill(Color.clear)
          .contentShape(DialRingHitShape(inset: ringInset, hitWidth: 42))
          .gesture(durationDragGesture)
          .accessibilityElement()
          .accessibilityLabel("专注时长")
          .accessibilityValue("\(displayedFocusMinutes) 分钟")
          .accessibilityHint("拖动圆环，或使用增减操作调整时长")
          .accessibilityAdjustableAction(adjustFocusDuration)
      }
    }
    .frame(width: dialSize, height: dialSize)
    .shadow(
      color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.07),
      radius: colorScheme == .dark ? 15 : 20,
      y: colorScheme == .dark ? 7 : 10
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onChange(of: controller.snapshot.timerMode) { _, _ in
      previewMinutes = nil
      lastDragMinutes = nil
    }
  }

  private var roundCountLabel: some View {
    Text("\(controller.snapshot.completedSessions) / \(controller.configuration.targetSessions)")
      .font(.system(size: 16, weight: .bold, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(.primary)
      .frame(width: 88, height: 34)
      .tideGlassCapsule(
        tint: colorScheme == .dark ? Color.white.opacity(0.025) : nil,
        interactive: controller.snapshot.runState == .idle
      )
  }

  private var modeSwitch: some View {
    ZStack {
      if isModeSelectionExpanded {
        HStack(spacing: 8) {
          ForEach(TimerMode.allCases) { mode in
            interactiveModeOption(mode)
              .matchedGeometryEffect(id: mode, in: modeSwitchNamespace)
          }
        }
        .transition(.opacity)
      } else {
        modePill(controller.snapshot.timerMode, selected: true, interactive: false)
          .matchedGeometryEffect(
            id: controller.snapshot.timerMode,
            in: modeSwitchNamespace
          )
          .accessibilityElement()
          .accessibilityLabel("\(collapsedModeTitle)，当前阶段")
      }
    }
    .frame(width: 132, height: 29)
    .animation(
      reduceMotion ? nil : .snappy(duration: 0.32, extraBounce: 0),
      value: isModeSelectionExpanded
    )
  }

  private func interactiveModeOption(_ mode: TimerMode) -> some View {
    let selected = controller.snapshot.timerMode == mode
    return Button {
      controller.setTimerMode(mode)
    } label: {
      modePill(mode, selected: selected, interactive: true)
    }
    .buttonStyle(.plain)
    .focusable(false)
    .accessibilityValue(selected ? "已选择" : "未选择")
  }

  private func modePill(_ mode: TimerMode, selected: Bool, interactive: Bool) -> some View {
    Text(modeTitle(for: mode))
      .font(.system(size: 11, weight: selected ? .semibold : .regular))
      .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.52))
      .padding(.horizontal, 12)
      .frame(height: 29)
      .contentShape(Capsule())
      .tideGlassCapsule(
        tint: selected
          ? Color.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.46)
          : nil,
        interactive: interactive
      )
  }

  private var collapsedModeTitle: String {
    modeTitle(for: controller.snapshot.timerMode)
  }

  private func modeTitle(for mode: TimerMode) -> String {
    if mode == .pomodoro,
       !isModeSelectionExpanded,
       controller.snapshot.phase.isBreak {
      return controller.snapshot.phase.title
    }
    return mode.title
  }

  private func breakLabel(for kind: BreakDurationKind) -> String {
    let seconds = kind.seconds(in: controller.configuration)
    return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)min"
  }

  private var activeBreakSummary: String {
    switch controller.snapshot.phase {
    case .focus:
      "短休息 \(breakLabel(for: .shortBreak)) · 长休息 \(breakLabel(for: .longBreak))"
    case .breakTime:
      "短休息 \(breakLabel(for: .shortBreak))"
    case .longBreak:
      "长休息 \(breakLabel(for: .longBreak))"
    }
  }

  @ViewBuilder
  private var breakDurationControls: some View {
    if controller.snapshot.runState == .idle {
      HStack(spacing: 6) {
        ForEach(BreakDurationKind.allCases) { kind in
          Button {
            editingBreakKind = kind
          } label: {
            Text("\(kind.compactTitle) \(breakLabel(for: kind))")
              .padding(.horizontal, 9)
              .frame(height: 25)
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .focusable(false)
          .tideGlassCapsule(interactive: true)
          .accessibilityLabel("设置\(kind.title)")
          .popover(
            isPresented: breakDurationPopoverBinding(for: kind),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
          ) {
            BreakDurationPopover(controller: controller, kind: kind) {
              editingBreakKind = nil
            }
          }
        }
      }
    } else {
      Text(activeBreakSummary)
        .frame(height: 25)
    }
  }

  private func breakDurationPopoverBinding(for kind: BreakDurationKind) -> Binding<Bool> {
    Binding(
      get: { editingBreakKind == kind },
      set: { isPresented in
        if isPresented {
          editingBreakKind = kind
        } else if editingBreakKind == kind {
          editingBreakKind = nil
        }
      }
    )
  }

  @ViewBuilder
  private var detailRegion: some View {
    if controller.snapshot.timerMode == .pomodoro {
      VStack(spacing: 4) {
        breakDurationControls
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)

        Group {
          if controller.snapshot.runState == .idle {
            Button {
              showingRoundEditor = true
            } label: {
              roundCountLabel
            }
            .buttonStyle(.plain)
            .focusable(false)
            .popover(isPresented: $showingRoundEditor, arrowEdge: .bottom) {
              RoundCountPopover(controller: controller) {
                showingRoundEditor = false
              }
            }
          } else {
            roundCountLabel
          }
        }

        Text("轮次")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(height: 13)
      }
    } else {
      Text(controller.snapshot.runState.title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(height: 25)
        .padding(.top, 7)
    }
  }

  private var durationDragGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .onChanged { value in
        let candidate = PomodoroDialScale.minutes(
          at: value.location,
          in: CGSize(width: dialSize, height: dialSize)
        )
        let previous = lastDragMinutes ?? controller.configuration.focusMinutes
        let resolved = PomodoroDialScale.resolvingOriginBoundary(
          candidate: candidate,
          previous: previous
        )
        guard resolved != lastDragMinutes else { return }
        previewMinutes = resolved
        lastDragMinutes = resolved
      }
      .onEnded { value in
        let candidate = PomodoroDialScale.minutes(
          at: value.location,
          in: CGSize(width: dialSize, height: dialSize)
        )
        let minutes = PomodoroDialScale.resolvingOriginBoundary(
          candidate: candidate,
          previous: lastDragMinutes ?? controller.configuration.focusMinutes
        )
        controller.setFocusMinutes(minutes)
        previewMinutes = nil
        lastDragMinutes = nil
      }
  }

  private func adjustFocusDuration(_ direction: AccessibilityAdjustmentDirection) {
    let delta: Int
    switch direction {
    case .increment: delta = 1
    case .decrement: delta = -1
    @unknown default: return
    }
    controller.setFocusMinutes(controller.configuration.focusMinutes + delta)
  }
}

private struct DialTickShape: Shape {
  var major: Bool

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outerRadius = min(rect.width, rect.height) / 2 - 20
    let innerRadius = outerRadius - (major ? 8 : 4)
    var path = Path()

    for index in 0..<60 where index.isMultiple(of: 5) == major {
      let angle = Double(index) * .pi / 30 - .pi / 2
      path.move(to: CGPoint(
        x: center.x + CGFloat(cos(angle)) * innerRadius,
        y: center.y + CGFloat(sin(angle)) * innerRadius
      ))
      path.addLine(to: CGPoint(
        x: center.x + CGFloat(cos(angle)) * outerRadius,
        y: center.y + CGFloat(sin(angle)) * outerRadius
      ))
    }
    return path
  }
}

private struct DialRingHitShape: Shape {
  var inset: CGFloat
  var hitWidth: CGFloat

  func path(in rect: CGRect) -> Path {
    Path(ellipseIn: rect.insetBy(dx: inset, dy: inset))
      .strokedPath(StrokeStyle(lineWidth: hitWidth))
  }
}

enum PomodoroDialScale {
  static let minuteRange = PomodoroConfiguration.focusMinutesRange

  static func fraction(for minutes: Int) -> Double {
    let clamped = min(max(minutes, minuteRange.lowerBound), minuteRange.upperBound)
    return Double(clamped) / Double(minuteRange.upperBound)
  }

  static func minutes(at point: CGPoint, in size: CGSize) -> Int {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let angleFromTop = atan2(point.y - center.y, point.x - center.x) + .pi / 2
    let normalized = (angleFromTop + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
    let rawMinutes = Int((normalized / (2 * .pi) * Double(minuteRange.upperBound)).rounded())
    return min(max(rawMinutes, minuteRange.lowerBound), minuteRange.upperBound)
  }

  static func resolvingOriginBoundary(candidate: Int, previous: Int) -> Int {
    let lowerBoundary = minuteRange.lowerBound
    let upperBoundary = minuteRange.upperBound
    let seamWindow = 12
    let clampedCandidate = min(max(candidate, lowerBoundary), upperBoundary)
    let clampedPrevious = min(max(previous, lowerBoundary), upperBoundary)

    if clampedPrevious <= lowerBoundary + seamWindow,
       clampedCandidate >= upperBoundary - seamWindow {
      return lowerBoundary
    }
    if clampedPrevious >= upperBoundary - seamWindow,
       clampedCandidate <= lowerBoundary + seamWindow {
      return upperBoundary
    }
    return clampedCandidate
  }

  static func isOnRing(
    _ point: CGPoint,
    in size: CGSize,
    inset: CGFloat = 7.5,
    tolerance: CGFloat = 21
  ) -> Bool {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = hypot(point.x - center.x, point.y - center.y)
    let targetRadius = min(size.width, size.height) / 2 - inset
    return abs(radius - targetRadius) <= tolerance
  }
}

private enum ClipoControlRole {
  case primary
  case skipRest
  case destructive
}

private struct ClipoControlButton: View {
  var symbol: String
  var label: String
  var enabled: Bool
  var role: ClipoControlRole
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      ClipoControlSurface(
        symbol: symbol,
        label: label,
        enabled: enabled,
        role: role
      )
    }
    .buttonStyle(ClipoControlPressStyle())
    .focusable(false)
    .disabled(!enabled)
    .accessibilityLabel(label)
    .help(label)
  }
}

private struct ClipoControlSurface: View {
  @Environment(\.colorScheme) private var colorScheme

  var symbol: String
  var label: String
  var enabled: Bool
  var role: ClipoControlRole

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        ZStack {
          Image(systemName: symbol)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(foreground)
            .shadow(color: symbolShadowColor, radius: 1.5, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tideGlassRect(
          cornerRadius: 22,
          tint: tint,
          interactive: enabled,
          backingOpacity: enabled ? 0.11 : 0.18
        )
        .overlay {
          ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [
                    Color.white.opacity(enabled ? (colorScheme == .dark ? 0.19 : 0.28) : 0.14),
                    Color.white.opacity(0.035),
                    Color.black.opacity(enabled ? 0.08 : 0.045),
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .blendMode(.screen)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
              .strokeBorder(
                LinearGradient(
                  colors: [
                    Color.white.opacity(enabled ? (colorScheme == .dark ? 0.46 : 0.82) : 0.36),
                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.2),
                    Color.black.opacity(enabled ? 0.16 : 0.09),
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1.15
              )

            Capsule()
              .fill(
                Color.white.opacity(
                  enabled ? (colorScheme == .dark ? 0.15 : 0.27) : 0.1
                )
              )
              .frame(width: 72, height: 2)
              .blur(radius: 0.35)
              .frame(maxHeight: .infinity, alignment: .top)
              .padding(.top, 4)
          }
          .allowsHitTesting(false)
        }
      }
      .frame(width: 118, height: 58)
      .shadow(
        color: Color.white.opacity(
          enabled ? (colorScheme == .dark ? 0.07 : 0.13) : 0.05
        ),
        radius: 2,
        y: -1
      )
      .shadow(
        color: glowColor,
        radius: enabled ? (colorScheme == .dark ? 14 : 20) : 10,
        y: colorScheme == .dark ? 6 : 9
      )

      Text(label)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(titleForeground)
    }
    .contentShape(Rectangle())
  }

  private var foreground: Color {
    guard enabled else { return Color.secondary.opacity(0.4) }
    switch role {
    case .primary, .destructive:
      return .white
    case .skipRest:
      return Color.white.opacity(0.96)
    }
  }

  private var titleForeground: Color {
    guard enabled else { return Color.secondary.opacity(0.45) }
    if role == .destructive {
      return colorScheme == .dark
        ? Color(hex: "#FF7180")
        : Color.red.opacity(0.86)
    }
    return Color.primary.opacity(0.78)
  }

  private var tint: Color? {
    guard enabled else { return nil }
    switch role {
    case .destructive:
      return colorScheme == .dark
        ? Color(hex: "#FF7180").opacity(0.68)
        : Color.red.opacity(0.58)
    case .primary:
      return Color.accentColor.opacity(colorScheme == .dark ? 0.54 : 0.64)
    case .skipRest:
      return Color(hex: TidePalette.skipRestAccentHex)
        .opacity(colorScheme == .dark ? 0.42 : 0.52)
    }
  }

  private var glowColor: Color {
    guard enabled else { return Color.black.opacity(0.08) }
    switch role {
    case .destructive:
      return colorScheme == .dark
        ? Color(hex: "#FF6174").opacity(0.15)
        : Color.red.opacity(0.24)
    case .primary:
      return Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.3)
    case .skipRest:
      return Color(hex: TidePalette.skipRestAccentHex)
        .opacity(colorScheme == .dark ? 0.12 : 0.22)
    }
  }

  private var symbolShadowColor: Color {
    guard enabled, role == .skipRest else { return .clear }
    return Color(hex: TidePalette.skipRestAccentHex)
      .opacity(colorScheme == .dark ? 0.28 : 0.36)
  }
}

private struct ClipoControlPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.965 : 1)
      .brightness(configuration.isPressed ? -0.05 : 0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private enum BreakDurationKind: CaseIterable, Identifiable {
  case shortBreak
  case longBreak

  var id: Self { self }

  var title: String {
    switch self {
    case .shortBreak: "短休息时长"
    case .longBreak: "长休息时长"
    }
  }

  var compactTitle: String {
    switch self {
    case .shortBreak: "短休息"
    case .longBreak: "长休息"
    }
  }

  var minutesRange: ClosedRange<Int> {
    switch self {
    case .shortBreak: PomodoroConfiguration.breakMinutesRange
    case .longBreak: PomodoroConfiguration.longBreakMinutesRange
    }
  }

  var presets: [Int] {
    switch self {
    case .shortBreak: PomodoroConfiguration.breakSecondPresets
    case .longBreak: PomodoroConfiguration.longBreakSecondPresets
    }
  }

  func seconds(in configuration: PomodoroConfiguration) -> Int {
    switch self {
    case .shortBreak: configuration.breakSeconds
    case .longBreak: configuration.longBreakSeconds
    }
  }

  @MainActor
  func apply(minutes: Int, to controller: PomodoroController) {
    switch self {
    case .shortBreak: controller.setBreakMinutes(minutes)
    case .longBreak: controller.setLongBreakMinutes(minutes)
    }
  }
}

private struct BreakDurationPopover: View {
  var controller: PomodoroController
  var kind: BreakDurationKind
  var onClose: () -> Void

  @State private var draftMinutes: Int

  init(controller: PomodoroController, kind: BreakDurationKind, onClose: @escaping () -> Void) {
    self.controller = controller
    self.kind = kind
    self.onClose = onClose
    let roundedMinutes = (kind.seconds(in: controller.configuration) + 59) / 60
    _draftMinutes = State(initialValue: min(
      max(roundedMinutes, kind.minutesRange.lowerBound),
      kind.minutesRange.upperBound
    ))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(kind.title)
          .font(.system(size: 14, weight: .bold))
        Spacer()
        Text("应用后生效")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.tertiary)
      }

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
        ForEach(kind.presets, id: \.self) { seconds in
          Button {
            draftMinutes = seconds / 60
          } label: {
            Text(label(seconds))
              .frame(maxWidth: .infinity)
              .contentShape(Capsule())
          }
          .clipoPresetButton(selected: draftMinutes * 60 == seconds)
          .accessibilityValue(draftMinutes * 60 == seconds ? "已选择，尚未应用" : "未选择")
        }
      }

      Divider()

      Text("自定义")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        customAdjustmentButton(
          symbol: "minus",
          enabled: draftMinutes > kind.minutesRange.lowerBound
        ) {
          draftMinutes -= 1
        }

        TextField("分钟", value: $draftMinutes, format: .number)
          .textFieldStyle(.plain)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .multilineTextAlignment(.center)
          .frame(width: 42, height: 30)
          .tideGlassCapsule()
          .onSubmit(applyCustomDuration)
          .accessibilityLabel("自定义\(kind.title)分钟数")

        Text("分钟")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)

        customAdjustmentButton(
          symbol: "plus",
          enabled: draftMinutes < kind.minutesRange.upperBound
        ) {
          draftMinutes += 1
        }

        Spacer(minLength: 0)

        Button("应用", action: applyCustomDuration)
          .clipoCapsuleButton(prominent: true)
          .accessibilityValue("设置为 \(draftMinutes) 分钟")
      }
    }
    .padding(15)
    .frame(width: 280)
    .tideGlassRect(cornerRadius: 16, backingOpacity: 0.58)
    .onAppear {
      let roundedMinutes = (kind.seconds(in: controller.configuration) + 59) / 60
      draftMinutes = min(
        max(roundedMinutes, kind.minutesRange.lowerBound),
        kind.minutesRange.upperBound
      )
    }
    .onExitCommand(perform: onClose)
  }

  private func label(_ seconds: Int) -> String {
    "\(seconds / 60)min"
  }

  private func customAdjustmentButton(
    symbol: String,
    enabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 10, weight: .bold))
        .frame(width: 30, height: 30)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassCircle(interactive: enabled)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
  }

  private func applyCustomDuration() {
    let minutes = min(
      max(draftMinutes, kind.minutesRange.lowerBound),
      kind.minutesRange.upperBound
    )
    draftMinutes = minutes
    kind.apply(minutes: minutes, to: controller)
    onClose()
  }
}

private struct RoundCountPopover: View {
  var controller: PomodoroController
  var onClose: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Text("番茄钟轮次")
        .font(.system(size: 14, weight: .bold))
      HStack(spacing: 14) {
        Button { controller.setTargetSessions(controller.configuration.targetSessions - 1) } label: {
          Image(systemName: "minus").frame(width: 28, height: 28)
        }
        .clipoCapsuleButton()
        .accessibilityLabel("减少轮次")
        Text("\(controller.configuration.targetSessions)")
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .monospacedDigit()
          .frame(width: 42)
        Button { controller.setTargetSessions(controller.configuration.targetSessions + 1) } label: {
          Image(systemName: "plus").frame(width: 28, height: 28)
        }
        .clipoCapsuleButton()
        .accessibilityLabel("增加轮次")
      }
      Button("完成", action: onClose)
        .clipoCapsuleButton(prominent: true)
    }
    .padding(15)
    .frame(width: 210)
    .tideGlassRect(cornerRadius: 16, backingOpacity: 0.58)
  }
}
