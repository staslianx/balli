//
//  RecipeMealSelectionView.swift
//  balli
//
//  Modal view for selecting recipe meal type and style
//  Two-step selection: categories first, then subcategories
//

import SwiftUI

struct RecipeMealSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedMealType: String
    @Binding var selectedStyleType: String

    let onGenerate: () -> Void

    @State private var selectedCategory: RecipeCategory?

    // Category structure matching RecipeSubcategory
    private enum RecipeCategory: String, CaseIterable {
        case kahvalti = "Kahvaltı"
        case salatalar = "Salatalar"
        case aksamYemegi = "Akşam yemeği"
        case tatlilar = "Tatlılar"
        case atistirmalik = "Atıştırmalık"

        var displayName: String {
            rawValue
        }

        var icon: String {
            switch self {
            case .kahvalti: return "☀️"
            case .salatalar: return "🥗"
            case .aksamYemegi: return "🍽️"
            case .tatlilar: return "🍰"
            case .atistirmalik: return "🥜"
            }
        }

        var subcategories: [String] {
            switch self {
            case .kahvalti:
                return []  // No subcategories
            case .salatalar:
                return ["Doyurucu Salata", "Hafif Salata"]
            case .aksamYemegi:
                return ["Karbonhidrat ve Protein Uyumu", "Tam Buğday Makarna"]
            case .tatlilar:
                return ["Sana Özel Tatlılar", "Dondurma", "Meyve Salatası"]
            case .atistirmalik:
                return []  // No subcategories
            }
        }

        var hasSubcategories: Bool {
            !subcategories.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if selectedCategory == nil {
                    // Step 1: Show category list
                    categoryListView
                } else {
                    // Step 2: Show subcategory list (if applicable)
                    subcategoryListView
                }
            }
            .navigationTitle(selectedCategory == nil ? "Kategori Seç" : selectedCategory?.displayName ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedCategory != nil {
                        Button(action: {
                            withAnimation {
                                selectedCategory = nil
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Geri")
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Category List View

    private var categoryListView: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                ForEach(RecipeCategory.allCases, id: \.self) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
            .padding(.top, ResponsiveDesign.Spacing.medium)
            .padding(.bottom, ResponsiveDesign.Spacing.xLarge)
        }
    }

    private func categoryCard(_ category: RecipeCategory) -> some View {
        Button(action: {
            if category.hasSubcategories {
                // Has subcategories - show subcategory list
                withAnimation {
                    selectedCategory = category
                }
            } else {
                // No subcategories - generate directly
                selectedMealType = category.rawValue
                selectedStyleType = ""
                onGenerate()
                dismiss()
            }
        }) {
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Icon
                Text(category.icon)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(28)))

                // Category name
                Text(category.displayName)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron indicator
                if category.hasSubcategories {
                    Image(systemName: "chevron.right")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, ResponsiveDesign.Spacing.small)
            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
            .contentShape(Rectangle())
            .background(.clear)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subcategory List View

    private var subcategoryListView: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                ForEach(selectedCategory?.subcategories ?? [], id: \.self) { subcategory in
                    subcategoryCard(subcategory)
                }
            }
            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
            .padding(.top, ResponsiveDesign.Spacing.medium)
            .padding(.bottom, ResponsiveDesign.Spacing.xLarge)
        }
    }

    private func subcategoryCard(_ subcategory: String) -> some View {
        Button(action: {
            selectedMealType = selectedCategory?.rawValue ?? ""
            selectedStyleType = subcategory
            onGenerate()
            dismiss()
        }) {
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Subcategory name
                Text(subcategory)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, ResponsiveDesign.Spacing.small)
            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
            .contentShape(Rectangle())
            .background(.clear)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Category List") {
    RecipeMealSelectionView(
        selectedMealType: .constant("Kahvaltı"),
        selectedStyleType: .constant(""),
        onGenerate: {
            print("Generate tapped")
        }
    )
}

#Preview("Subcategory List - Tatlılar") {
    RecipeMealSelectionView(
        selectedMealType: .constant("Tatlılar"),
        selectedStyleType: .constant("Sana Özel Tatlılar"),
        onGenerate: {
            print("Generate tapped")
        }
    )
}
