//
//  GradientBackground.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import SwiftUI

struct GradientBackground: View {
  @Environment(\.colorScheme) var colorScheme

  private func isDarkScheme() -> Bool {
    colorScheme == .dark
  }

  var body: some View {
    MeshGradient(
      width: 3,
      height: 3,
      points: [
        [0, 0], [0, isDarkScheme() ? 0.7 : 0.93], [0, 1],
        [0.8, 0], [isDarkScheme() ? 0.4 : 0.3, isDarkScheme() ? 0.7 : 0.5], [0.7, 1.0],
        [1, 0], [1, 0.4], [1, 1],
      ],
      colors: [
        Color("Gradient/Olive"),
        Color("Gradient/Olive"),
        Color("Gradient/Cyan"),

        Color("Gradient/Pahir"),
        Color("Gradient/Olive"),
        Color("Gradient/Pahir"),

        Color("Gradient/OliveTree"),
        Color("Gradient/Olive"),
        Color("Gradient/OliveTree"),
      ]
    )
  }
}

#Preview {
  GradientBackground()
}
