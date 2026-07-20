import CoreGraphics
import Testing
@testable import Tide

struct PomodoroDialScaleTests {
  private let size = CGSize(width: 280, height: 280)

  @Test func cardinalPointsMapToExpectedMinutes() {
    #expect(PomodoroDialScale.minutes(at: CGPoint(x: 140, y: 7.5), in: size) == 1)
    #expect(PomodoroDialScale.minutes(at: CGPoint(x: 272.5, y: 140), in: size) == 30)
    #expect(PomodoroDialScale.minutes(at: CGPoint(x: 140, y: 272.5), in: size) == 60)
    #expect(PomodoroDialScale.minutes(at: CGPoint(x: 7.5, y: 140), in: size) == 90)
  }

  @Test func durationFractionUsesFullOneToOneHundredTwentyMinuteRange() {
    #expect(abs(PomodoroDialScale.fraction(for: 1) - (1.0 / 120.0)) < 0.000_001)
    #expect(abs(PomodoroDialScale.fraction(for: 30) - 0.25) < 0.000_001)
    #expect(abs(PomodoroDialScale.fraction(for: 120) - 1) < 0.000_001)
    #expect(PomodoroDialScale.fraction(for: -10) == PomodoroDialScale.fraction(for: 1))
    #expect(PomodoroDialScale.fraction(for: 999) == 1)
  }

  @Test func onlyTheVisibleRingIsDraggable() {
    #expect(PomodoroDialScale.isOnRing(CGPoint(x: 140, y: 7.5), in: size))
    #expect(PomodoroDialScale.isOnRing(CGPoint(x: 272.5, y: 140), in: size))
    #expect(!PomodoroDialScale.isOnRing(CGPoint(x: 140, y: 140), in: size))
    #expect(!PomodoroDialScale.isOnRing(CGPoint(x: 140, y: 80), in: size))
  }

  @Test func originIsAFiniteBoundaryInsteadOfAWraparoundSeam() {
    #expect(PomodoroDialScale.resolvingOriginBoundary(candidate: 120, previous: 1) == 1)
    #expect(PomodoroDialScale.resolvingOriginBoundary(candidate: 1, previous: 120) == 120)
    #expect(PomodoroDialScale.resolvingOriginBoundary(candidate: 119, previous: 120) == 119)
    #expect(PomodoroDialScale.resolvingOriginBoundary(candidate: 2, previous: 1) == 2)
    #expect(PomodoroDialScale.resolvingOriginBoundary(candidate: 60, previous: 7) == 60)
  }
}
