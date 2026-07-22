import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipoSettingsPage: View {
  var controller: PomodoroController
  var updateController: TideUpdateController? = nil

  @Environment(\.colorScheme) private var colorScheme

  @State private var showingClearConfirmation = false
  @State private var exportError: String?

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
        TideGlassContainer(spacing: 17) {
          VStack(spacing: 17) {
            Text("设置")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity)
              .padding(.top, 12)

            GlassCard {
              VStack(alignment: .leading, spacing: 13) {
                Text("外观")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)
                HStack(spacing: 7) {
                  ForEach(TideAppearance.allCases) { appearance in
                    let selected = controller.configuration.appearance == appearance
                    Button {
                      controller.setAppearance(appearance)
                    } label: {
                      Text(appearance.title)
                        .frame(maxWidth: .infinity)
                        .contentShape(Capsule())
                    }
                    .clipoPresetButton(selected: selected)
                    .accessibilityValue(selected ? "已选择" : "未选择")
                  }
                }
              }
            }

            GlassCard {
              VStack(alignment: .leading, spacing: 12) {
                Text("专注时长")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                  settingCircleButton(symbol: "minus", label: "减少专注时长") {
                    controller.setFocusMinutes(controller.configuration.focusMinutes - 1)
                  }
                  Text("\(controller.configuration.focusMinutes) 分钟")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .tideGlassCapsule()
                  settingCircleButton(symbol: "plus", label: "增加专注时长") {
                    controller.setFocusMinutes(controller.configuration.focusMinutes + 1)
                  }
                }

                Divider().overlay(TideTheme.border(colorScheme))

                Text("番茄钟轮次")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                  settingCircleButton(symbol: "minus", label: "减少番茄钟轮次") {
                    controller.setTargetSessions(controller.configuration.targetSessions - 1)
                  }
                  Text("\(controller.configuration.targetSessions)")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .tideGlassCapsule()
                  settingCircleButton(symbol: "plus", label: "增加番茄钟轮次") {
                    controller.setTargetSessions(controller.configuration.targetSessions + 1)
                  }
                }
              }
            }

            GlassCard {
              VStack(alignment: .leading, spacing: 11) {
                Text("通知提醒")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)
                Toggle("通知提醒", isOn: notificationBinding)
                  .font(.system(size: 12, weight: .semibold))
                  .toggleStyle(.switch)
                  .controlSize(.small)
                  .tint(.accentColor)
                  .focusable(false)
                if controller.configuration.notificationsEnabled {
                  Text("结束前 1 分钟轻提醒，结束时再播放一次提示音。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Text(controller.notificationAuthorization.statusText)
                  .font(.system(size: 10, weight: .medium))
                  .foregroundStyle(
                    controller.notificationAuthorization == .denied
                      ? Color.orange
                      : Color.secondary
                  )
                if controller.configuration.notificationsEnabled,
                   controller.notificationAuthorization != .denied {
                  Button {
                    controller.sendTestNotification()
                  } label: {
                    Label(
                      controller.testNotificationState == .sending
                        ? "正在发送…"
                        : "发送测试提醒",
                      systemImage: controller.testNotificationState == .sending
                        ? "arrow.triangle.2.circlepath"
                        : "bell.badge"
                    )
                      .frame(maxWidth: .infinity)
                      .contentShape(Capsule())
                  }
                  .clipoCapsuleButton()
                  .disabled(controller.testNotificationState == .sending)
                  .accessibilityLabel("发送一条 Tide 测试提醒")

                  if let statusText = controller.testNotificationState.statusText {
                    Label(statusText, systemImage: testNotificationStatusSymbol)
                      .font(.system(size: 10, weight: .medium))
                      .foregroundStyle(testNotificationStatusColor)
                      .fixedSize(horizontal: false, vertical: true)
                      .transition(.opacity.combined(with: .move(edge: .top)))
                      .accessibilityLabel("测试提醒状态，\(statusText)")
                  }
                }
                if controller.notificationAuthorization == .denied {
                  Button(action: openSystemNotificationSettings) {
                    Label("打开系统通知设置", systemImage: "arrow.up.forward.app")
                      .frame(maxWidth: .infinity)
                      .contentShape(Capsule())
                  }
                  .clipoCapsuleButton()
                  .accessibilityLabel("打开 macOS 系统通知设置")
                }
              }
            }

            GlassCard {
              VStack(spacing: 12) {
                Button {
                  showingClearConfirmation = true
                } label: {
                  HStack {
                    Text("清除番茄钟数据")
                      .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "trash")
                      .font(.system(size: 11, weight: .bold))
                      .frame(width: 29, height: 29)
                      .tideGlassCircle(tint: Color.red.opacity(0.2))
                  }
                  .foregroundStyle(Color.red.opacity(0.88))
                  .padding(.horizontal, 11)
                  .frame(height: 40)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .tideGlassRect(
                  cornerRadius: 12,
                  tint: Color.red.opacity(0.14),
                  interactive: true
                )
                .popover(isPresented: $showingClearConfirmation) {
                  ClipoConfirmationPopover(
                    title: "清除番茄钟数据",
                    message: "所有专注完成记录将被永久清除，标签与计时设置会保留。",
                    confirmTitle: "清除",
                    destructive: true,
                    onCancel: { showingClearConfirmation = false },
                    onConfirm: {
                      showingClearConfirmation = false
                      controller.clearHistory()
                    }
                  )
                }

                Divider().overlay(TideTheme.border(colorScheme))

                HStack {
                  Text("导出专注记录")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                  Spacer()
                  Button("CSV") { export(.csv) }
                    .clipoCapsuleButton()
                  Button("JSON") { export(.json) }
                    .clipoCapsuleButton()
                }

                if let exportError {
                  Text(exportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }

            GlassCard {
              VStack(alignment: .leading, spacing: 12) {
                Text("关于与更新")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text("Tide")
                      .font(.system(size: 12, weight: .semibold))
                      .foregroundStyle(.primary)
                    Text("版本 \(versionText)")
                      .font(.system(size: 10, weight: .medium))
                      .foregroundStyle(.secondary)
                  }

                  Spacer()

                  Button {
                    updateController?.checkForUpdates()
                  } label: {
                    Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                      .contentShape(Capsule())
                  }
                  .clipoCapsuleButton()
                  .disabled(!(updateController?.canCheckForUpdates ?? false))
                  .accessibilityLabel("检查 Tide 更新")
                }

                Divider().overlay(TideTheme.border(colorScheme))

                Button(action: quitApplication) {
                  HStack {
                    Label("退出 Tide", systemImage: "power")
                      .font(.system(size: 12, weight: .semibold))
                    Spacer()
                  }
                  .foregroundStyle(.primary.opacity(0.82))
                  .padding(.horizontal, 11)
                  .frame(height: 40)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .tideGlassRect(
                  cornerRadius: 12,
                  tint: Color.primary.opacity(0.04),
                  interactive: true
                )
                .accessibilityLabel("退出 Tide 应用")
                .help("退出 Tide")
              }
            }
          }
          .padding(.horizontal, 28)
          .padding(.bottom, 24)
        }
    }
    .animation(.easeOut(duration: 0.18), value: controller.testNotificationState)
  }

  private var testNotificationStatusSymbol: String {
    switch controller.testNotificationState {
    case .idle: "bell"
    case .sending: "clock"
    case .scheduled: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    }
  }

  private var testNotificationStatusColor: Color {
    switch controller.testNotificationState {
    case .failed: .orange
    case .scheduled: .accentColor
    case .idle, .sending: .secondary
    }
  }

  private var notificationBinding: Binding<Bool> {
    Binding(
      get: { controller.configuration.notificationsEnabled },
      set: { controller.setNotificationsEnabled($0) }
    )
  }

  private var versionText: String {
    let version = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return "\(version ?? "0.0.1") (\(build ?? "1"))"
  }

  private func quitApplication() {
    NSApplication.shared.terminate(nil)
  }

  private func settingCircleButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.primary)
        .frame(width: 38, height: 38)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassCircle(interactive: true)
    .accessibilityLabel(label)
    .help(label)
  }

  private func openSystemNotificationSettings() {
    guard let url = URL(
      string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
    ) else { return }
    NSWorkspace.shared.open(url)
  }

  private func export(_ format: PomodoroExportFormat) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "Tide-Pomodoro-\(Self.fileDate.string(from: .now)).\(format.fileExtension)"
    panel.allowedContentTypes = format == .csv ? [.commaSeparatedText] : [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try PomodoroExportService.data(for: controller.archive, format: format)
      try data.write(to: url, options: .atomic)
      exportError = nil
    } catch {
      exportError = "导出失败：\(error.localizedDescription)"
    }
  }

  private static let fileDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}
