import Observation
import SwiftUI

enum TidePopoverMetrics {
  static let width: CGFloat = 420
  static let timerHeight: CGFloat = 542
  static let statisticsHeight: CGFloat = 604

  static func height(for page: TidePage) -> CGFloat {
    switch page {
    case .timer: timerHeight
    case .statistics: statisticsHeight
    }
  }
}

enum TideTheme {
  static func background(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: "#101820") : Color(hex: "#F3F4F6")
  }

  static func raisedSurface(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: "#1A242E") : .white
  }

  static func surface(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.065) : Color.black.opacity(0.045)
  }

  static func border(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
  }

  static func defaultGlassBackingOpacity(_ scheme: ColorScheme) -> Double {
    scheme == .dark ? 0.18 : 0
  }

  static func resolvedGlassTint(_ tint: Color?, scheme: ColorScheme) -> Color? {
    tint.map { $0.opacity(scheme == .dark ? 0.72 : 1) }
  }
}

struct TideGlassContainer<Content: View>: View {
  var spacing: CGFloat = 16
  @ViewBuilder var content: Content

  @ViewBuilder
  var body: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: spacing) {
        content
      }
    } else {
      content
    }
  }
}

private struct TideGlassRectModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  var cornerRadius: CGFloat
  var tint: Color?
  var interactive: Bool
  var backingOpacity: Double

  @ViewBuilder
  func body(content: Content) -> some View {
    let resolvedTint = TideTheme.resolvedGlassTint(tint, scheme: colorScheme)
    let resolvedBackingOpacity = max(
      backingOpacity,
      TideTheme.defaultGlassBackingOpacity(colorScheme)
    )

    if #available(macOS 26.0, *) {
      content.glassEffect(
        .regular.tint(resolvedTint).interactive(interactive),
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
      .background {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(TideTheme.raisedSurface(colorScheme).opacity(resolvedBackingOpacity))
      }
    } else {
      let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      content
        .background(.ultraThinMaterial, in: shape)
        .background(TideTheme.raisedSurface(colorScheme).opacity(resolvedBackingOpacity), in: shape)
        .overlay { shape.fill((resolvedTint ?? .clear).opacity(0.14)).allowsHitTesting(false) }
        .overlay { shape.stroke(TideTheme.border(colorScheme), lineWidth: 1).allowsHitTesting(false) }
    }
  }
}

private struct TideGlassCapsuleModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  var tint: Color?
  var interactive: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    let resolvedTint = TideTheme.resolvedGlassTint(tint, scheme: colorScheme)
    let backingOpacity = TideTheme.defaultGlassBackingOpacity(colorScheme)

    if #available(macOS 26.0, *) {
      content
        .glassEffect(.regular.tint(resolvedTint).interactive(interactive), in: Capsule())
        .background {
          Capsule()
            .fill(TideTheme.raisedSurface(colorScheme).opacity(backingOpacity))
        }
    } else {
      content
        .background(.ultraThinMaterial, in: Capsule())
        .background(TideTheme.raisedSurface(colorScheme).opacity(backingOpacity), in: Capsule())
        .overlay { Capsule().fill((resolvedTint ?? .clear).opacity(0.14)).allowsHitTesting(false) }
        .overlay { Capsule().stroke(TideTheme.border(colorScheme), lineWidth: 1).allowsHitTesting(false) }
    }
  }
}

private struct TideGlassCircleModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  var tint: Color?
  var interactive: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    let resolvedTint = TideTheme.resolvedGlassTint(tint, scheme: colorScheme)

    if #available(macOS 26.0, *) {
      content.glassEffect(.regular.tint(resolvedTint).interactive(interactive), in: Circle())
    } else {
      content
        .background(.ultraThinMaterial, in: Circle())
        .overlay { Circle().fill((resolvedTint ?? .clear).opacity(0.14)).allowsHitTesting(false) }
        .overlay { Circle().stroke(TideTheme.border(colorScheme), lineWidth: 1).allowsHitTesting(false) }
    }
  }
}

private struct TideIdentityGlassTransitionModifier: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      content.glassEffectTransition(.identity)
    } else {
      content
    }
  }
}

extension View {
  func tideGlassRect(
    cornerRadius: CGFloat = 16,
    tint: Color? = nil,
    interactive: Bool = false,
    backingOpacity: Double = 0
  ) -> some View {
    modifier(TideGlassRectModifier(
      cornerRadius: cornerRadius,
      tint: tint,
      interactive: interactive,
      backingOpacity: backingOpacity
    ))
  }

  func tideGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
    modifier(TideGlassCapsuleModifier(tint: tint, interactive: interactive))
  }

  func tideGlassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
    modifier(TideGlassCircleModifier(tint: tint, interactive: interactive))
  }

  func tideIdentityGlassTransition() -> some View {
    modifier(TideIdentityGlassTransitionModifier())
  }
}

enum TidePage: Sendable, Equatable {
  case timer
  case statistics
}

@MainActor
@Observable
final class TidePresentationState {
  var page: TidePage = .timer
  private(set) var timerEntranceRevision = 0
  private(set) var timerEntranceDelayMilliseconds = 0

  func showTimer() {
    timerEntranceDelayMilliseconds = 20
    timerEntranceRevision &+= 1
    page = .timer
  }

  func prepareForPopoverPresentation() {
    guard page == .timer else { return }
    timerEntranceDelayMilliseconds = 90
    timerEntranceRevision &+= 1
  }
}

struct ClipoBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  var body: some View {
    if colorScheme == .dark {
      TideTheme.background(colorScheme)
        .opacity(0.62)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    } else {
      Color.clear
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
  }
}

struct ClipoToolbar: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var controller: PomodoroController
  var presentation: TidePresentationState
  var updateController: TideUpdateController?

  @State private var showingSettings = false

  var body: some View {
    HStack(spacing: 10) {
      TideBrandLockup()

      Spacer(minLength: 8)

      ZStack {
        if presentation.page == .statistics {
          backButton
            .transition(.asymmetric(
              insertion: .offset(x: 28).combined(with: .opacity),
              removal: .offset(x: 12).combined(with: .opacity)
            ))
        }
      }
      .frame(width: 64, height: 34)
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.26),
        value: presentation.page
      )

      Button {
        showingSettings = true
      } label: {
        Label("设置", systemImage: "gearshape")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.78))
          .padding(.horizontal, 12)
          .frame(height: 34)
          .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .focusable(false)
      .tideGlassCapsule(interactive: true)
      .popover(isPresented: $showingSettings, arrowEdge: .top) {
        ZStack {
          ClipoBackground()
          ClipoSettingsPage(
            controller: controller,
            updateController: updateController
          )
        }
        .frame(width: 380, height: 530)
      }
      .accessibilityLabel("打开设置")
    }
    .padding(.horizontal, 27)
    .frame(height: 62)
  }

  private var backButton: some View {
    Button {
      presentation.showTimer()
    } label: {
      Label("计时", systemImage: "chevron.left")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.primary.opacity(0.78))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .focusable(false)
    .tideGlassCapsule(interactive: true)
    .tideIdentityGlassTransition()
    .accessibilityLabel("返回计时")
  }

}

private struct TideBrandLockup: View {
  private var version: String {
    let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    return "v\(value ?? "1.0.0")"
  }

  var body: some View {
    HStack(spacing: 8) {
      TideLogoMark()

      VStack(alignment: .leading, spacing: 0) {
        Text("Tide")
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundStyle(.primary.opacity(0.9))

        Text(version)
          .font(.system(size: 8, weight: .medium, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
    }
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Tide，版本 \(version.dropFirst())")
  }
}

private struct TideLogoMark: View {
  @Environment(\.colorScheme) private var colorScheme

  private var brandColor: Color {
    Color(hex: TidePalette.brandAccentHex)
  }

  private var glyphColor: Color {
    if colorScheme == .dark {
      return Color(red: 0.45, green: 0.65, blue: 0.86).opacity(0.9)
    }
    return Color.white.opacity(0.96)
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(brandColor.opacity(colorScheme == .dark ? 0.38 : 0.58))

      TideWaveGlyph()
        .stroke(
          glyphColor,
          style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
        )
        .frame(width: 17, height: 12)
        .offset(y: 2)

      Circle()
        .fill(glyphColor)
        .frame(width: 3.5, height: 3.5)
        .offset(x: 5, y: -6)
    }
    .frame(width: 30, height: 30)
    .tideGlassCircle(
      tint: brandColor.opacity(colorScheme == .dark ? 0.3 : 0.42)
    )
    .overlay {
      Circle()
        .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.58), lineWidth: 0.8)
        .allowsHitTesting(false)
    }
    .shadow(color: brandColor.opacity(colorScheme == .dark ? 0.12 : 0.14), radius: 7, y: 3)
    .accessibilityHidden(true)
  }
}

private struct TideWaveGlyph: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let left = rect.minX + 0.5
    let right = rect.maxX - 0.5
    let width = right - left

    func addWave(y: CGFloat) {
      path.move(to: CGPoint(x: left, y: y))
      path.addCurve(
        to: CGPoint(x: left + width / 2, y: y),
        control1: CGPoint(x: left + width * 0.14, y: y - 3.1),
        control2: CGPoint(x: left + width * 0.36, y: y + 3.1)
      )
      path.addCurve(
        to: CGPoint(x: right, y: y),
        control1: CGPoint(x: left + width * 0.64, y: y - 3.1),
        control2: CGPoint(x: left + width * 0.86, y: y + 3.1)
      )
    }

    addWave(y: rect.minY + rect.height * 0.36)
    addWave(y: rect.minY + rect.height * 0.72)
    return path
  }
}

struct GlassCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(15)
      .tideGlassRect(cornerRadius: 16)
  }
}

struct ClipoCapsuleButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme

  var selected = false
  var prominent = false
  var destructive = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.72 : 1))
      .padding(.horizontal, 14)
      .frame(minHeight: 31)
      .tideGlassCapsule(tint: tint, interactive: isEnabled)
      .contentShape(Capsule())
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(isEnabled ? 1 : 0.38)
  }

  private var tint: Color? {
    if destructive {
      return colorScheme == .dark
        ? Color(hex: "#FF7180").opacity(0.66)
        : Color.red.opacity(0.5)
    }
    if selected || prominent { return Color.accentColor.opacity(0.48) }
    return nil
  }

  private var foreground: Color {
    destructive || selected || prominent ? .white : .primary
  }
}

struct ClipoPresetButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  var selected = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle((selected ? Color.white : Color.primary).opacity(configuration.isPressed ? 0.72 : 1))
      .frame(maxWidth: .infinity, minHeight: 32)
      .contentShape(Capsule())
      .tideGlassCapsule(
        tint: selected ? Color.accentColor.opacity(0.48) : nil,
        interactive: isEnabled
      )
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(isEnabled ? 1 : 0.38)
  }
}

extension View {
  func clipoCapsuleButton(selected: Bool = false, prominent: Bool = false, destructive: Bool = false) -> some View {
    buttonStyle(ClipoCapsuleButtonStyle(selected: selected, prominent: prominent, destructive: destructive))
      .focusable(false)
  }

  func clipoPresetButton(selected: Bool = false) -> some View {
    buttonStyle(ClipoPresetButtonStyle(selected: selected))
      .focusable(false)
  }
}

struct ClipoConfirmationPopover: View {
  var title: String
  var message: String
  var confirmTitle: String
  var destructive: Bool
  var onCancel: () -> Void
  var onConfirm: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.primary)

        Text(message)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(spacing: 10) {
        Button(action: onCancel) {
          Text("取消")
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Capsule())
        }
        .clipoCapsuleButton()
        .keyboardShortcut(.cancelAction)

        Button(action: onConfirm) {
          Text(confirmTitle)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Capsule())
        }
        .clipoCapsuleButton(prominent: !destructive, destructive: destructive)
      }
      .padding(.top, 18)
    }
    .padding(.horizontal, 18)
    .padding(.top, 18)
    .padding(.bottom, 16)
    .frame(width: 286)
    .onExitCommand(perform: onCancel)
  }
}
