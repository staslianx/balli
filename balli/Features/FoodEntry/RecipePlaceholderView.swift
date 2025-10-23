//
//  RecipePlaceholderView.swift
//  balli
//
//  Placeholder view for recipe entry
//

import SwiftUI

struct RecipePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: ResponsiveDesign.Spacing.large) {
                    Spacer()
                    
                    // Icon
                    Image(systemName: "book.fill")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(80)))
                        .foregroundColor(AppTheme.primaryPurple)
                        .padding(.bottom, ResponsiveDesign.Spacing.medium)
                    
                    // Title
                    Text("Tarif Girişi")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(28), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Description
                    Text("Bu özellik yakında kullanıma sunulacak")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ResponsiveDesign.Spacing.large)
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
    }
}

#Preview {
    RecipePlaceholderView()
}