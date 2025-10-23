//
//  AIResultToolbar.swift
//  balli
//
//  Action buttons toolbar for AI result view
//

import SwiftUI

/// Toolbar containing action buttons for AI result view
struct AIResultToolbar: View {
    @ObservedObject var viewModel: AIResultViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    let onSave: () -> Void
    
    var body: some View {
        // Primary actions only
        HStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Save button
            Button(action: onSave) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20)))
                    Text("Kaydet")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.height(56))
                .background(AppTheme.adaptiveBalliGradient(for: colorScheme))
                .clipShape(Capsule())
                .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: ResponsiveDesign.height(4), x: 0, y: ResponsiveDesign.height(2))
            }
            .disabled(viewModel.uiState.isSaving)
            .opacity(viewModel.uiState.isSaving ? 0.6 : 1.0)

            // Edit button
            Button(action: { viewModel.toggleEditMode() }) {
                HStack {
                    Image(systemName: viewModel.uiState.isEditing ? "checkmark" : "pencil")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20)))
                    Text(viewModel.uiState.isEditing ? "Bitti" : "Düzenle")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                }
                .foregroundColor(AppTheme.primaryPurple)
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.height(56))
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(AppTheme.primaryPurple, lineWidth: 2)
                )
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }
}

// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}