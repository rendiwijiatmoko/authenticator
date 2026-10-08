//
//  AuthenticatorTheme.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import SwiftUI

enum AuthenticatorTheme {
    static let primary = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
    static let accent = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let dark = Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255)
    static let gradient = LinearGradient(colors: [primary, accent], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : Color(red: 0.95, green: 0.96, blue: 0.98)
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func glassSurface(radius: CGFloat = 24) -> some View {
        modifier(GlassSurface(radius: radius))
    }
}
