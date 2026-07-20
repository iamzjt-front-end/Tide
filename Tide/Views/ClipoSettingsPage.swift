import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipoSettingsPage: View {
  var controller: PomodoroController

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
                Text(controller.notificationAuthorization.statusText)
                  .font(.system(size: 10, weight: .medium))
                  .foregroundStyle(
                    controller.notificationAuthorization == .denied
                      ? Color.orange
                      : Color.secondary
                  )
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
          }
          .padding(.horizontal, 28)
          .padding(.bottom, 24)
        }
    }
  }

  private var notificationBinding: Binding<Bool> {
    Binding(
      get: { controller.configuration.notificationsEnabled },
      set: { controller.setNotificationsEnabled($0) }
    )
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
