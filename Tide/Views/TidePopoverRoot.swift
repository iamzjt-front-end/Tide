import SwiftUI

struct TidePopoverRoot: View {
  var controller: PomodoroController
  var presentation: TidePresentationState
  var onPreferredHeightChange: ((CGFloat) -> Void)?

  init(
    controller: PomodoroController,
    presentation: TidePresentationState,
    onPreferredHeightChange: ((CGFloat) -> Void)? = nil
  ) {
    self.controller = controller
    self.presentation = presentation
    self.onPreferredHeightChange = onPreferredHeightChange
  }

  var body: some View {
    ZStack {
      ClipoBackground()
      VStack(spacing: 0) {
        ClipoToolbar(
          controller: controller,
          presentation: presentation
        )
        page
      }

      if let banner = controller.banner {
        TidePopoverBanner(banner: banner)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(.top, 20)
          .allowsHitTesting(false)
          .transition(.move(edge: .top).combined(with: .opacity))
          .task(id: banner.id) {
            let duration = banner.kind == .phaseReady ? 4.2 : 1.7
            try? await Task.sleep(for: .seconds(duration))
            controller.dismissBanner(id: banner.id)
          }
      }

      if let error = controller.persistentError {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
          Text(error)
            .font(.caption)
            .lineLimit(2)
          Button {
            controller.dismissPersistentError()
          } label: {
            Image(systemName: "xmark")
              .frame(width: 24, height: 24)
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .focusable(false)
        }
        .foregroundStyle(.primary)
        .padding(10)
        .frame(width: 360)
        .tideGlassRect(cornerRadius: 12, tint: Color.red.opacity(0.16))
        .offset(y: preferredHeight / 2 - 50)
      }
    }
    .frame(width: TidePopoverMetrics.width, height: preferredHeight)
    .tint(themeColor)
    .accentColor(themeColor)
    .animation(.easeOut(duration: 0.16), value: controller.banner)
    .animation(.easeInOut(duration: 0.18), value: controller.currentAccentHex)
    .onAppear {
      onPreferredHeightChange?(preferredHeight)
    }
    .onChange(of: presentation.page) { _, newPage in
      onPreferredHeightChange?(TidePopoverMetrics.height(for: newPage))
    }
  }

  private var preferredHeight: CGFloat {
    TidePopoverMetrics.height(for: presentation.page)
  }

  private var themeColor: Color {
    Color(hex: controller.currentAccentHex)
  }

  @ViewBuilder
  private var page: some View {
    switch presentation.page {
    case .timer:
      ClipoTimerPage(
        controller: controller,
        entranceRevision: presentation.timerEntranceRevision,
        entranceDelayMilliseconds: presentation.timerEntranceDelayMilliseconds
      ) {
        presentation.page = .statistics
      }
    case .statistics:
      ClipoStatisticsPage(controller: controller)
    }
  }
}

private struct TidePopoverBanner: View {
  var banner: TideBanner

  var body: some View {
    Label(
      banner.text,
      systemImage: symbolName
    )
    .font(.system(size: banner.kind == .phaseReady ? 10 : 9, weight: .semibold))
    .foregroundStyle(.primary.opacity(0.84))
    .lineLimit(1)
    .padding(.horizontal, banner.kind == .phaseReady ? 12 : 9)
    .frame(height: banner.kind == .phaseReady ? 28 : 22)
    .fixedSize(horizontal: true, vertical: false)
    .tideGlassCapsule(
      tint: banner.kind == .info
        ? Color.primary.opacity(0.06)
        : Color.accentColor.opacity(banner.kind == .phaseReady ? 0.22 : 0.14)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("提示，\(banner.text)")
  }

  private var symbolName: String {
    switch banner.kind {
    case .success: "checkmark.circle.fill"
    case .info: "info.circle.fill"
    case .phaseReady: "bell.badge.fill"
    }
  }
}
