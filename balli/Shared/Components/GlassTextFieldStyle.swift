//
//  GlassTextFieldStyle.swift
//  balli
//
//  Reusable glass effect text field style
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct GlassTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.clear)
            )
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func glassTextField() -> some View {
        modifier(GlassTextFieldStyle())
    }
}
