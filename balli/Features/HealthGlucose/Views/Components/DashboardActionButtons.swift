//
//  DashboardActionButtons.swift
//  balli
//
//  Dashboard action buttons component
//

import SwiftUI

struct DashboardActionButtons: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var showingCamera: Bool
    @Binding var showingManualEntry: Bool
    @Binding var showingRecipeEntry: Bool
    @Binding var isLongPressing: Bool

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Tarif button - direct navigation
                Button(action: {
                    showingRecipeEntry = true
                }) {
                    HStack(spacing: ResponsiveDesign.height(10)) {
                        Text("tarif")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 24, weight: .regular, design: .rounded))
                    }
                    .foregroundColor(colorScheme == .dark ? .primary : .white)
                    .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.Components.actionButtonHeight+10)
                    .background(
                        colorScheme == .light ? AppTheme.adaptiveBalliGradient(for: colorScheme) : nil
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.Components.actionButtonHeight / 2, style: .continuous))
                    .glassEffect(
                        colorScheme == .dark ? .regular.interactive() : .regular,
                        in: RoundedRectangle(cornerRadius: ResponsiveDesign.Components.actionButtonHeight / 2, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                // Nedu? button - tap for camera, long press for manual entry
                HStack(spacing: ResponsiveDesign.height(10)) {
                    Image(systemName: "laser.burst")
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                    Text("nedu?")
                        .font(.passionOne(34, weight: .regular))
                }
                .foregroundColor(colorScheme == .dark ? .primary : .white)
                .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.Components.actionButtonHeight+10)
                .background(
                    colorScheme == .light ? AppTheme.adaptiveBalliGradient(for: colorScheme) : nil
                )
                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.Components.actionButtonHeight / 2, style: .continuous))
                .glassEffect(
                    colorScheme == .dark ? .regular.interactive() : .regular,
                    in: RoundedRectangle(cornerRadius: ResponsiveDesign.Components.actionButtonHeight / 2, style: .continuous)
                )
                .scaleEffect(isLongPressing ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isLongPressing)
                .onTapGesture {
                    // Regular tap - show camera
                    showingCamera = true
                }
                .onLongPressGesture(
                    minimumDuration: 0.5,
                    perform: {
                        // Long press action - show manual entry
                        showingManualEntry = true
                    },
                    onPressingChanged: { pressing in
                        isLongPressing = pressing
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 22)
    }
}
